# Research Report: Literature Agent Design Patterns

**Task**: 758 - Unified Literature System
**Dimension**: Agent design — replacing context injection with autonomous exploration
**Completed**: 2026-06-23

## Executive Summary

- The current system uses two parallel injection scripts (`literature-retrieve.sh`, `zotero-retrieve.sh`) that dump scored content into agent prompts as `<literature-context>` / `<zotero-context>` blocks, consuming 4,000–8,000 tokens whether the agent uses them or not
- The proposed literature-agent should follow the existing agent definition format (YAML frontmatter + markdown body) and be invocable as a **tool-like teammate** rather than a replacement for injection — other agents call it when they need literature context
- The agent needs four core operations: search-by-keyword, read-chunk, get-metadata, and cross-reference — all implementable via Bash calls to scripts against the global index
- Two viable invocation patterns exist: (A) spawn as a teammate alongside research agents, or (B) expose as a callable tool/skill that research agents invoke mid-execution

## 1. Current Architecture: Context Injection

### How `--lit` works today

1. Command parses `--lit` flag → sets `lit_flag=true` in delegation context
2. Skill preflight (e.g., `skill-researcher` Stage 4a) calls `literature-retrieve.sh "$description" "$task_type"`
3. Script scores `specs/literature/index.json` entries by keyword overlap (MIN_SCORE=1), greedy-selects within TOKEN_BUDGET=8000, MAX_FILES=10
4. Returns a `<literature-context>` block containing full file contents of matched entries
5. Skill injects this block into the agent prompt, between format spec and task instructions

### How `--zot` works today

Same pattern but via `zotero-retrieve.sh`, scoring against `specs/zotero-index.json` with a heavier weighted formula (title×4, tags×3, abstract×2, keywords×2, collections×1, notes×1) and MIN_SCORE=4. Has three paths: chunked content, PDF-available metadata, metadata-only.

### Problems with injection

| Problem | Detail |
|---------|--------|
| Token waste | Always injects up to budget even if agent only needs 1 paragraph |
| No selectivity | Agent cannot ask follow-up questions or drill into specific sections |
| Blind scoring | Keyword overlap is a crude proxy; agent would score better with semantic understanding |
| Two parallel systems | `--lit` and `--zot` inject independently with different scoring, indices, and schemas |
| Prompt bloat | Injection happens at prompt construction time; context is fixed for the agent's entire run |

## 2. Existing Agent Patterns in This System

### Agent definition format

All agents in `.claude/agents/` follow this structure:

```yaml
---
name: agent-name
description: Brief description
model: sonnet  # or opus, haiku
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion  # etc.
---

# Agent Name

## Overview
## Context References
## Execution Flow (Stages 0-N)
## Error Handling
## Critical Requirements
```

Key observations from existing agents:
- **Tool access is declared in frontmatter** (`allowed-tools`), not dynamically composed
- **Agents receive context via prompt injection** — the calling skill constructs a prompt with delegation context JSON, format specs, and optional memory/literature blocks
- **Agents write artifacts and metadata** — they create files in `specs/{NNN}_{SLUG}/` and write `.return-meta.json`
- **Agents are spawned via the Agent tool** with `subagent_type` matching the agent name

### Invocation patterns

| Pattern | Example | How it works |
|---------|---------|--------------|
| Skill → Agent | skill-researcher → general-research-agent | Skill constructs prompt, spawns agent, reads metadata after |
| Direct execution | skill-literature, skill-memory | Skill runs inline, no subagent |
| Team orchestration | skill-team-research → N teammates + synthesis-agent | Skill spawns parallel agents, then synthesis agent reads all outputs |

## 3. Proposed Literature Agent Design

### 3A. Agent-as-Teammate Pattern

The literature-agent runs **alongside** the research/implementation agent as a teammate, pre-fetching relevant literature and writing a findings file. The primary agent then reads the findings file.

```
skill-researcher (preflight)
    |
    +-- Spawn literature-agent (teammate)
    |     Input: task description + sub-index path
    |     Output: specs/{NNN}/reports/{NN}_literature-findings.md
    |
    +-- Spawn general-research-agent (primary)
    |     Input: delegation context + @path to literature-findings.md
    |     Reads literature findings only if/when needed
    |
    v
postflight
```

**Pros**: Clean separation of concerns; literature agent has its own context window; primary agent reads selectively.
**Cons**: Sequential dependency (literature-agent must finish before primary agent can read its output); may over-fetch if run in parallel.

### 3B. Agent-as-Tool Pattern (Recommended)

The literature-agent is exposed as a **callable skill/tool** that other agents invoke mid-execution when they need literature context. This is the pattern the user described: "the agent can explore the literature for themselves."

```
general-research-agent (running)
    |
    +-- Encounters question about modal logic semantics
    |
    +-- Calls: Bash("literature-search.sh 'modal logic semantics'")
    |     Returns: ranked list of matching entries with metadata
    |
    +-- Calls: Read("$LITERATURE_DIR/Brastmckie_2024_BimodalLogic/section03_semantics.md")
    |     Returns: full section content
    |
    +-- Incorporates relevant content into research
    |
    v
continues with full context of what it read
```

**Pros**: Agent reads only what it needs; no wasted tokens; agent can iterate (search → read → search again); works with existing Read tool.
**Cons**: Requires agents to know the literature search interface exists; needs prompt instructions.

### 3C. Recommended Hybrid: Briefing + Tools

Combine a lightweight briefing (what's available) with on-demand tools (read what you need):

1. **At prompt construction**: Inject a compact **literature briefing** (not content) — just the sub-index metadata: titles, authors, keywords, token counts, paths. This costs ~200-500 tokens instead of 4,000-8,000.
2. **During execution**: Agent uses `Read` to access specific chunks and a `literature-search.sh` script for keyword search across the global index.

```
Prompt injection (lightweight):
  <literature-briefing>
  Available literature for this task (from specs/literature-index.json):
  1. "Propositional Logic" — Smith 2023 — 1,850 tokens — specs/literature/Smith_2023.md
  2. "BimodalLogic §2: Syntax" — Brastmckie 2024 — 2,100 tokens — specs/literature/.../section02_syntax.md
  3. "BimodalLogic §3: Semantics" — Brastmckie 2024 — 3,400 tokens — specs/literature/.../section03_semantics.md

  To read a paper: use Read tool with the path above.
  To search the full Literature corpus: Bash("literature-search.sh 'query terms'")
  </literature-briefing>

Agent execution:
  - Reads the briefing (~300 tokens)
  - Decides section03_semantics.md is relevant → Read(path)
  - Wants more → Bash("literature-search.sh 'Kripke frames completeness'") → discovers new entry
  - Reads that entry too
```

## 4. Tool Interface Design

### Required operations

| Operation | Implementation | Input | Output |
|-----------|---------------|-------|--------|
| **search** | `literature-search.sh "query"` | keyword query | JSON array of scored entries with metadata |
| **read-chunk** | `Read` tool (already exists) | absolute path to .md file | file content |
| **get-metadata** | `jq` against global index | entry ID or path | JSON metadata object |
| **cross-reference** | `literature-search.sh --related ID` | entry ID | entries sharing parent_doc or keywords |

### literature-search.sh (new unified script)

Replaces both `literature-retrieve.sh` and `zotero-retrieve.sh` with a single search interface:

```bash
# Search by keyword (returns JSON, does NOT inject content)
literature-search.sh "modal logic semantics"
# Output: [{"id": "...", "title": "...", "path": "...", "score": 5, "token_count": 2100, ...}, ...]

# Search with limit
literature-search.sh --limit 5 "completeness theorem"

# Get related entries (same parent_doc or keyword overlap)
literature-search.sh --related "brastmckie2024_bimodal_sec02"

# Get metadata for specific entry
literature-search.sh --entry "brastmckie2024_bimodal_sec02"
```

Key design choices:
- Returns **metadata only**, never file content — the agent decides what to read
- Works against the **global index** at `$LITERATURE_DIR/index.json` (not per-repo)
- Per-repo sub-index (`specs/literature-index.json`) acts as a **filter/boost**: entries in the sub-index get a relevance bonus, but the agent can discover entries outside the sub-index too

### Per-repo sub-index schema

```json
{
  "literature_dir": "/home/benjamin/Projects/Literature",
  "entries": [
    {
      "id": "brastmckie2024_bimodal",
      "relevance_note": "Core paper for this project",
      "added": "2026-06-20T12:00:00Z"
    }
  ]
}
```

Minimal: just entry IDs and optional notes. The global index holds all metadata. The sub-index says "these papers matter for this repo."

## 5. Agent Prompt Design

### Literature-aware agent instructions (added to research/planner/implementer prompts)

```markdown
## Literature Access

You have access to a curated literature corpus. A briefing of relevant papers is provided below.

**To read a paper section**: Use the Read tool with the path shown in the briefing.
**To search for more papers**: Run `bash $LITERATURE_DIR/search.sh "your query"` — returns JSON metadata, not content.
**To get related papers**: Run `bash $LITERATURE_DIR/search.sh --related "entry_id"`.

Read papers **selectively** — only when you need specific content for your task. Do not read all papers preemptively.
```

### Token efficiency analysis

| Approach | Tokens consumed | When |
|----------|----------------|------|
| Current `--lit` injection | 4,000-8,000 (always) | At prompt construction |
| Current `--zot` injection | 4,000-8,000 (always) | At prompt construction |
| Briefing + on-demand | 200-500 (briefing) + N×(chunk size) as needed | Briefing at prompt; reads during execution |

For a task where the agent needs one specific section (2,000 tokens), the new approach uses ~2,300 tokens vs. the current 8,000+.

## 6. Integration Points

### Where injection currently happens (files to modify)

| File | Current injection | New behavior |
|------|-------------------|--------------|
| `skill-researcher/SKILL.md` Stage 4a | Calls `literature-retrieve.sh`, injects `<literature-context>` | Generate briefing from sub-index, inject `<literature-briefing>` |
| `skill-planner/SKILL.md` Stage 4a | Same | Same |
| `skill-implementer/SKILL.md` Stage 4a | Same | Same |
| `skill-orchestrate/SKILL.md` | Threads `lit_flag`/`zot_flag` through all dispatches | Thread single `literature_flag` |
| `command-route-skill.sh` | Not directly involved (flags threaded via commands) | No change needed |
| Research/plan/implement commands | Parse `--lit` and `--zot` separately | Parse single `--lit` flag |

### Flag consolidation

Replace `--lit` + `--zot` with a single `--lit` flag:
- `--lit` = inject literature briefing + enable search tools
- No `--zot` needed — Zotero items are just entries in the global Literature index
- `--clean` still suppresses memory; `--lit` is independent

### Agent definition changes

The existing `literature-agent.md` and `zotero-agent.md` are documentation-only (direct-execution pattern). The new unified `literature-agent.md` would be a real agent if using Pattern 3A, or would remain documentation-only if using the recommended Pattern 3C (briefing + tools).

For Pattern 3C, no new agent definition is needed — the change is:
1. A new `literature-search.sh` script (replaces retrieve scripts)
2. A new `literature-briefing.sh` script (generates the compact briefing)
3. Modified skill preflights to generate briefing instead of full injection
4. Added literature-access instructions in agent prompts

## 7. Decisions and Recommendations

1. **Pattern 3C (Briefing + Tools)** is recommended — lowest implementation cost, best token efficiency, works with all existing agents without new agent types
2. **Single global index** at `$LITERATURE_DIR/index.json` — the unified source of truth
3. **Per-repo sub-index** as a lightweight relevance filter — just entry IDs, not duplicated metadata
4. **Single `--lit` flag** replacing both `--lit` and `--zot`
5. **`literature-search.sh`** as the unified search tool — returns metadata JSON, never content
6. **Agent Read tool** for actual content access — no new tools needed
7. **Briefing block** (~200-500 tokens) replaces injection block (4,000-8,000 tokens)

## Appendix: Files Examined

- `.claude/agents/literature-agent.md` — current literature agent (documentation-only)
- `.claude/agents/zotero-agent.md` — current zotero agent (documentation-only)
- `.claude/agents/general-research-agent.md` — reference for agent format and execution flow
- `.claude/agents/synthesis-agent.md` — reference for team-mode agent pattern
- `.claude/agents/spawn-agent.md` — reference for restricted-tool agent pattern
- `.claude/extensions/core/scripts/literature-retrieve.sh` — current `--lit` injection script
- `.claude/extensions/zotero/scripts/zotero-retrieve.sh` — current `--zot` injection script
- `.claude/skills/skill-researcher/SKILL.md` — current injection integration point
- `.claude/skills/skill-orchestrate/SKILL.md` — current flag threading
