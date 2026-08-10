# Research Report: Task #758 (Teammate A)

**Task**: 758 - Unified Literature System
**Focus**: --lit Flag Lifecycle Wiring
**Started**: 2026-06-23T21:00:00Z
**Completed**: 2026-06-23T21:30:00Z
**Effort**: 0.5 hours
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (parse-command-args.sh, literature-retrieve.sh, literature-search.sh, skill-researcher/SKILL.md, skill-planner/SKILL.md, skill-implementer/SKILL.md, skill-orchestrate/SKILL.md, specs/758_unified_literature_system/plans/05_unified-literature-plan.md)
**Artifacts**: specs/758_unified_literature_system/reports/06_teammate-a-findings.md
**Standards**: report-format.md

---

## Executive Summary

- The `--lit` flag is fully wired through all five lifecycle stages: parsing, preflight retrieval, skill injection, agent prompting, and orchestrate threading. The wiring is consistent across all three skill types (researcher, planner, implementer).
- The current injection mechanism (`literature-retrieve.sh`) does keyword scoring and returns full file content wrapped in `<literature-context>` tags; the new system should call `literature-briefing.sh` instead and produce `<literature-briefing>` tags with compact metadata.
- The orchestrate skill already threads `lit_flag` through all dispatch contexts (research, plan, implement) using a string value extracted from the delegation context at Stage 0/1; the wiring path for the new briefing system is identical.
- `literature-search.sh` already exists as an agent-callable FTS5 tool with a comprehensive CLI interface; agents can invoke it via `Bash` and access chunks via `Read`.
- The recommended approach is a surgical find-and-replace in Stages 4a of three SKILL.md files: change `literature-retrieve.sh` -> `literature-briefing.sh` and `<literature-context>` -> `<literature-briefing>`. No changes are needed to parse-command-args.sh, skill-orchestrate, or the agent dispatch chain.

---

## Context & Scope

This report covers the exact wiring of the `--lit` flag through the agent lifecycle, with the goal of understanding what must change to switch from static full-content injection to a compact briefing + on-demand tools pattern.

---

## Findings

### 1. Current --lit Parsing (parse-command-args.sh)

`LIT_FLAG` is parsed in `parse-command-args.sh` lines 112-114:

```bash
if [[ "$remaining" =~ --lit ]]; then
  LIT_FLAG="true"
fi
```

It is exported alongside all other flags (line 138). No changes needed here. The flag is parsed correctly and `--zot` does not appear in this file (the plan's Phase 4 note to confirm ZOT_FLAG absence is already confirmed).

### 2. Current Injection in Skill Preflights (Stage 4a)

All three skill types have identical Stage 4a literature injection blocks. From `skill-researcher/SKILL.md` (lines 168-179), replicated verbatim in `skill-planner/SKILL.md` (lines 179-192) and `skill-implementer/SKILL.md` (lines 160-174):

```bash
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-retrieve.sh "$description" "$task_type" 2>/dev/null) || lit_context=""
fi
```

In Stage 5, the `lit_context` is injected after `<memory-context>` and before task instructions:

```
{lit_context from Stage 4a -- already wrapped in <literature-context> tags}
```

**Critical observation**: The existing injection position is already correct for the new system. The swap is purely mechanical: replace the script call and the tag name.

### 3. Current Retrieval Mechanism (literature-retrieve.sh)

`literature-retrieve.sh` at `.claude/scripts/literature-retrieve.sh`:

- **Token budget**: 8,000 (or from `index.json.token_budget`)
- **Max files**: 10
- **Scoring**: Keyword overlap between task description/type and entry keywords + summary bonus
- **Output format**: `<literature-context>` wrapping full file content (can be thousands of tokens)
- **Fallback**: File scan when index.json missing or no keyword matches
- **Index sources**: Root `specs/literature/index.json` + subdirectory index.json files (chapters[] format normalized to entries[] shape)

This is the component being replaced by `literature-briefing.sh` in the new design.

### 4. What `literature-briefing.sh` Should Produce

Based on the plan (Phase 3, lines 151-157) and the briefing+tools design principle, the new briefing generator should:

- Read `specs/literature-index.json` (per-repo sub-index with `doc_id` entries)
- Look up full metadata from `$LITERATURE_DIR/index.json` (title, authors, year, token_count, chunk paths)
- Output a compact `<literature-briefing>` block, ~300-500 tokens max
- Include usage instructions: how to use `Read` for chunks and how to call `literature-search.sh`

Example output format:

```
<literature-briefing>
Available literature for this task (3 sources):

1. **Blackburn et al., 2001** — "Modal Logic" (doc_id: blackburn_2001_modal_logic)
   Chunks: ~/Projects/Literature/blackburn_2001_modal_logic/chunk_001.md (2,100 tokens), ...
   Total: 42 chunks, ~88,000 tokens

2. **Fitting & Mendelsohn, 1998** — "First-Order Modal Logic" (doc_id: fitting_1998_foml)
   Chunks: ~/Projects/Literature/fitting_1998_foml/chunk_001.md ...

To read: use Read tool with chunk path.
To search: Bash('.claude/scripts/literature-search.sh "your query"')
To browse TOC: Bash('.claude/scripts/literature-search.sh --toc blackburn_2001_modal_logic')
</literature-briefing>
```

### 5. The Agent-Callable Tool Interface (literature-search.sh)

`literature-search.sh` at `.claude/scripts/literature-search.sh` is fully implemented with FTS5 search:

- `literature-search.sh "query"` — BM25-ranked full-text search returning JSON: chunk_id, doc_id, title, section_path, summary, snippet (200 chars), token_count, cross_refs
- `literature-search.sh --read <chunk_id>` — returns full chunk content as JSON
- `literature-search.sh --toc [doc_id]` — lists all chunks without content
- `literature-search.sh --refs <chunk_id>` — follow cross-references
- `literature-search.sh --next/--prev <chunk_id>` — sequential navigation
- `literature-search.sh --doc <doc_id>` — list all chunks for one document

Searches both `specs/literature/.literature.db` (local) and `~/Projects/Literature/.literature.db` (global), with local results taking precedence on duplicate doc_id. The `--project <name>` flag filters by project_tags in the global index.

**For the new briefing+tools pattern**: agents use `Bash` to call `literature-search.sh` for searching and `Read` to access chunk files directly at known paths. Both tools are already available in all agent tool sets.

### 6. Orchestrate Wiring (skill-orchestrate/SKILL.md)

`lit_flag` is extracted from the delegation context in Stage 0 (line 37) and Stage 1 (line 62):

```bash
lit_flag=$(echo "$delegation_context" | jq -r '.lit_flag // "false"')
```

It is then passed through all three dispatch contexts (research, plan, implement) as a string literal in the JSON:

- Research dispatch (State: `not_started`): `"lit_flag": "'$lit_flag'"`
- Plan dispatch (State: `researched`): `"lit_flag": "'$lit_flag'"`
- Implement dispatch (State: `planned`/`implementing`): `"lit_flag": "'$lit_flag'"`
- Continuation dispatch (State: `partial`): `"lit_flag": "'$lit_flag'"`

In Multi-Task Mode (Stage MT-4), the same pattern applies for all three dispatch contexts (lines 1015-1018, 1038-1041, 1068-1072).

**The orchestrate skill does NOT call `literature-retrieve.sh` or `literature-briefing.sh` directly.** It passes `lit_flag` as a string to the downstream agent, and those agents' skill preflights handle the actual briefing injection. This is the correct separation: orchestrate threads the flag, skills consume it.

### 7. The `zot_flag` Thread

The orchestrate skill also reads and threads `zot_flag` identically to `lit_flag` (Stage 0 line 38, Stage 1 line 63). It appears in all dispatch contexts alongside `lit_flag`. Per the plan's Phase 4 task, `zot_flag` threading should be removed from skill-orchestrate after consolidation. No changes are needed to `parse-command-args.sh` since `--zot` was never wired there.

### 8. Integration Points Summary

| Integration Point | Current Behavior | New Behavior |
|---|---|---|
| `parse-command-args.sh` | Parses `--lit` -> `LIT_FLAG=true` | **No change needed** |
| `skill-researcher/SKILL.md` Stage 4a | Calls `literature-retrieve.sh` | Call `literature-briefing.sh` |
| `skill-planner/SKILL.md` Stage 4a | Calls `literature-retrieve.sh` | Call `literature-briefing.sh` |
| `skill-implementer/SKILL.md` Stage 4a | Calls `literature-retrieve.sh` | Call `literature-briefing.sh` |
| Stage 5 prompt injection | `<literature-context>` block | `<literature-briefing>` block |
| `skill-orchestrate/SKILL.md` Stage 0/1 | Reads `lit_flag` from delegation | **No change needed** |
| Orchestrate dispatch contexts | `"lit_flag": "'$lit_flag'"` | **No change needed** |
| Agent access to literature | None (content pre-injected) | `Bash(literature-search.sh ...)` + `Read` chunk path |

---

## Recommendations

### Recommended Approach: Surgical Three-File Swap

The wiring is clean and the change is minimal. For Phase 4 of the implementation plan:

**In each of the three skill SKILL.md files (skill-researcher, skill-planner, skill-implementer), change Stage 4a from:**

```bash
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-retrieve.sh "$description" "$task_type" 2>/dev/null) || lit_context=""
fi
```

**To:**

```bash
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/extensions/literature/scripts/literature-briefing.sh 2>/dev/null) || lit_context=""
fi
```

Note: `literature-briefing.sh` reads `specs/literature-index.json` directly and needs no arguments — it does not take description/task_type because it does not do keyword scoring. The sub-index is already scoped to relevant documents by the user when they ran `/literature --add`.

**In Stage 5 of each skill, change the injection comment from:**

```
{lit_context from Stage 4a -- already wrapped in <literature-context> tags}
```

**To:**

```
{lit_context from Stage 4a -- already wrapped in <literature-briefing> tags}
```

**For skill-orchestrate**: Remove the `zot_flag` read and threading. Keep `lit_flag` threading unchanged.

**For agent prompts**: Add a paragraph in the Stage 5 prompt template of each skill:

```
When literature-briefing is present, you can access papers on demand:
- To search: Bash('bash .claude/scripts/literature-search.sh "your query"')
- To read a chunk: use the Read tool with the absolute path from the briefing
- To browse document TOC: Bash('bash .claude/scripts/literature-search.sh --toc <doc_id>')
```

### Briefing Generator Design

`literature-briefing.sh` should follow this flow:

1. Read `specs/literature-index.json` — if absent, exit 1 (no output)
2. Read `$LITERATURE_DIR/index.json` (global index) for metadata lookup
3. For each `doc_id` in the sub-index:
   - Look up title, authors, year from global index
   - Count chunks (from `chapter_count` or file glob)
   - Emit compact entry with absolute chunk paths
4. Wrap in `<literature-briefing>` tags with usage instructions
5. Enforce ~500 token budget (truncate entry list if needed)

The script does not accept `description` or `task_type` arguments. The sub-index is already relevance-filtered by the user. This simplifies the interface from the current `literature-retrieve.sh "description" "task_type"` signature.

### Distinction from Current System

| Dimension | Current (--lit) | New (--lit) |
|---|---|---|
| Input args | `description task_type` (for scoring) | None (sub-index is pre-filtered) |
| Output size | 4,000-8,000 tokens (full content) | ~300-500 tokens (briefing only) |
| Agent access | Pre-injected (passive) | On-demand via Bash + Read (active) |
| Source | `specs/literature/` dir | `specs/literature-index.json` -> `$LITERATURE_DIR` |
| Tag | `<literature-context>` | `<literature-briefing>` |
| Search | Not available in agent | `literature-search.sh` via Bash |

---

## Decisions

- The flag parsing layer (`parse-command-args.sh`) requires no changes — `LIT_FLAG` is already wired correctly.
- The orchestrate state machine requires only removal of `zot_flag` threading; `lit_flag` threading is already correct for the new system.
- The briefing generator should live at `.claude/extensions/literature/scripts/literature-briefing.sh` (in the unified extension, not in `.claude/scripts/`).
- The skill preflights should call it via the extension path, not a copy in `.claude/scripts/`.
- No agent-type-specific wiring is needed — the `lit_flag` threading in orchestrate already covers research-agent, planner-agent, and implementation-agent dispatches uniformly.

---

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| `literature-briefing.sh` path differs from `literature-retrieve.sh` (in scripts/ not extension scripts/) | Skills will reference extension path; ensure extension is loaded before --lit is used |
| Sub-index empty or missing causes silent --lit no-op | Script exits 1, skill sets `lit_context=""`, no block injected — same behavior as current system when no matches |
| Agents may not know to use Bash for literature-search.sh | Add explicit tool-access instructions in Stage 5 prompt of each skill |
| Hard skill variants (skill-researcher-hard, skill-planner-hard, skill-implementer-hard) also need Stage 4a updates | Check each hard variant SKILL.md for equivalent injection block |

---

## Context Extension Recommendations

- **Topic**: literature-briefing pattern documentation
- **Gap**: No context file documents the briefing+tools agent interaction pattern for literature access
- **Recommendation**: Create `.claude/extensions/literature/context/project/literature/patterns/agent-exploration.md` (referenced in the plan as a new file to create) documenting how agents use `Read` + `literature-search.sh` for on-demand literature access

---

## Appendix

### Files Read

- `/home/benjamin/.config/nvim/.claude/scripts/parse-command-args.sh` (lines 1-141)
- `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh` (lines 1-212)
- `/home/benjamin/.config/nvim/.claude/scripts/literature-search.sh` (lines 1-689)
- `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md` (lines 1-512)
- `/home/benjamin/.config/nvim/.claude/skills/skill-planner/SKILL.md` (lines 1-546)
- `/home/benjamin/.config/nvim/.claude/skills/skill-implementer/SKILL.md` (lines 1-250)
- `/home/benjamin/.config/nvim/.claude/skills/skill-orchestrate/SKILL.md` (lines 1-1253)
- `/home/benjamin/.config/nvim/specs/758_unified_literature_system/plans/05_unified-literature-plan.md` (lines 1-307)

### Key Line References

- `LIT_FLAG` parsing: `parse-command-args.sh` lines 112-114
- `lit_context` injection pattern: `skill-researcher/SKILL.md` lines 168-272
- Orchestrate `lit_flag` extraction: `skill-orchestrate/SKILL.md` lines 37, 62
- Orchestrate research dispatch with `lit_flag`: `skill-orchestrate/SKILL.md` lines 207-208
- Orchestrate plan dispatch with `lit_flag`: `skill-orchestrate/SKILL.md` lines 234-235
- Orchestrate implement dispatch with `lit_flag`: `skill-orchestrate/SKILL.md` lines 256-259
- Multi-task research dispatch: `skill-orchestrate/SKILL.md` lines 1014-1018
- Multi-task plan dispatch: `skill-orchestrate/SKILL.md` lines 1038-1041
- Multi-task implement dispatch: `skill-orchestrate/SKILL.md` lines 1062-1072
