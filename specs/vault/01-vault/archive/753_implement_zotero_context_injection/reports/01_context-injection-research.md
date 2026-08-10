# Research Report: Task #753

**Task**: 753 - Implement Zotero context injection (--zot flag)
**Started**: 2026-06-19T00:00:00Z
**Completed**: 2026-06-19T01:00:00Z
**Effort**: ~2 hours
**Dependencies**: Task 752 (zotero-chunk.sh), Task 750 (zotero-read.sh), Task 751 (zotero-search-index.sh)
**Sources/Inputs**:
- `specs/748_design_zotero_extension_architecture/summaries/01_zotero-arch-design.md`
- `.claude/scripts/literature-retrieve.sh` (direct template)
- `.claude/scripts/command-route-skill.sh`
- `.claude/extensions/zotero/scripts/zotero-retrieve.sh` (existing stub)
- `.claude/skills/skill-researcher/SKILL.md`, `skill-planner/SKILL.md`, `skill-implementer/SKILL.md`
- `.claude/skills/skill-orchestrate/SKILL.md`
- `.claude/commands/research.md`, `plan.md`, `implement.md`
**Artifacts**: - specs/753_implement_zotero_context_injection/reports/01_context-injection-research.md
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- `zotero-retrieve.sh` must be implemented from scratch following the 8-step algorithm in arch-design Section 5/6, using `literature-retrieve.sh` as the structural template
- The `--zot` flag requires wiring into 7 files: `command-route-skill.sh` is NOT the injection point — the flag flows through the command files as `zot_flag` in delegation context, and the three skill files (skill-researcher, skill-planner, skill-implementer) plus skill-orchestrate are where `zotero-retrieve.sh` is actually called
- The installed `.claude/scripts/` directory does NOT have the zotero scripts installed — they exist only in `.claude/extensions/zotero/scripts/`. The scripts must also be copied to `.claude/scripts/` to be usable (or called via extension path)
- `command-route-skill.sh` does NOT handle `--lit`/`--zot` flags at all — it only resolves skill names from task type. The architecture design's suggestion to wire `--zot` there is incorrect; the actual injection happens in the skill SKILL.md files
- CLAUDE.md currently says "--zot flag wiring is implemented in task 753" — this note must be removed after implementation
- All 7 injection points follow an identical pattern, making the change straightforward and low-risk

---

## Context & Scope

Task 753 is the final task in the 5-task Zotero extension chain (749→750→751→752→753). Its scope is:

1. Implement `zotero-retrieve.sh` — the context injection script analogous to `literature-retrieve.sh`
2. Wire the `--zot` flag into command parsing (commands) and context injection (skills)
3. Ensure composability with `--lit`, `--clean`, `--hard`, `--team`
4. Token budget enforcement and chunk-level retrieval via `literature-search.sh`
5. On-demand conversion trigger (if entry has PDF but no chunks: surface convert suggestion)

---

## Findings

### Codebase Patterns

#### 1. literature-retrieve.sh Structure (Direct Template)

The `literature-retrieve.sh` script is the exact structural template for `zotero-retrieve.sh`. Key observations:

- **Two paths**: Index path (when `specs/literature/index.json` exists + description provided) and fallback path (directory scan)
- **Keyword extraction**: Tokenize description + task_type, filter stop words, length > 3, sort + deduplicate, take first 10
- **Token budget**: Read from `index.json`'s `token_budget` field, fallback to constant `TOKEN_BUDGET=8000`
- **Greedy selection**: `reduce .[] as $entry` accumulating tokens until budget exhausted
- **Output format**: `<literature-context>\n...content...\n</literature-context>`
- **Exit 0 always** (even when empty) except exit 1 if directory missing

For `zotero-retrieve.sh`, there is NO fallback path (no directory scan) — it only has the index path. If `specs/zotero-index.json` missing or empty, silently exit 0 with empty output.

#### 2. Scoring Algorithm (Arch-Design Section 6)

The zotero scoring is significantly more complex than literature's simple keyword overlap:

```
score = title_score * 4 + tag_score * 3 + abstract_score * 2 +
        keyword_score * 2 + collection_score * 1 + notes_score * 1
```

**Threshold**: `>= 4` (vs literature's `>= 1`)

The jq pseudocode from arch-design Section 6 is directly implementable:
```jq
def score_field(text; weight):
  if (text == null or text == "") then 0
  else (text | ascii_downcase) as $t |
    reduce $terms[] as $term (0;
      if ($t | test($term; "i")) then . + weight else . end)
  end;

def score_array(arr; weight):
  if (arr == null or (arr | length) == 0) then 0
  else reduce arr[] as $el (0; score_field($el; weight))
  end;

(score_field(.title; 4) + score_array(.tags; 3) +
 score_field(.abstract_snippet; 2) + score_array(.keywords; 2) +
 score_array(.collections; 1) + score_field(.notes_summary; 1)) as $total |
if $total >= 4 then . + {"_score": $total} else empty end
```

#### 3. The Real Wiring Location: Skills, Not command-route-skill.sh

**Critical finding**: The architecture design (Section 8) incorrectly identifies `command-route-skill.sh` as the wiring location. That script only resolves skill names from task types. The `--lit` flag is wired in the **skill SKILL.md files** (not in `command-route-skill.sh`).

Exact pattern from `skill-researcher/SKILL.md` Stage 4a:
```bash
# Literature context injection (independent of clean_flag)
lit_context=""
if [ "$lit_flag" = "true" ]; then
  lit_context=$(bash .claude/scripts/literature-retrieve.sh "$description" "$task_type" 2>/dev/null) || lit_context=""
fi
```

This same pattern must be replicated for `zot_flag`/`zotero-retrieve.sh` in:
- `skill-researcher/SKILL.md`
- `skill-planner/SKILL.md`
- `skill-implementer/SKILL.md`
- `skill-orchestrate/SKILL.md`

#### 4. The Flag Flows Through Delegation Context

The `--zot` flag is parsed in command files and passed as `zot_flag` in the delegation context JSON. Looking at `research.md`:

- Stage 1.5 parses `--lit` → `lit_flag = true` and removes it from remaining args
- The flag is passed to skills via `args: "... lit_flag={lit_flag}"`
- Skills read: `lit_flag=$(echo "$delegation_context" | jq -r '.lit_flag // "false"')`

For `--zot`, the exact same pattern is needed:
- Parse `--zot` → `zot_flag = true` in Stage 1.5 of each command
- Pass `zot_flag={zot_flag}` in skill args
- Skills read `zot_flag` from delegation context

#### 5. Files That Need Changes

**7 files total** require modification:

| File | Change Type | Description |
|------|-------------|-------------|
| `commands/research.md` | Add `--zot` flag parsing in Stage 1.5 | Parse `--zot` → `zot_flag=true`, remove from focus_prompt extraction, pass in args |
| `commands/plan.md` | Add `--zot` flag parsing in Stage 1.5 | Same as research.md |
| `commands/implement.md` | Add `--zot` flag parsing in Stage 1.5 | Same as research.md |
| `skills/skill-researcher/SKILL.md` | Add `zot_context` block in Stage 4a | After `lit_context` block, add matching `zot_context` block |
| `skills/skill-planner/SKILL.md` | Add `zot_context` block in Stage 4a | Same as skill-researcher |
| `skills/skill-implementer/SKILL.md` | Add `zot_context` block in Stage 4a | Same as skill-researcher |
| `skills/skill-orchestrate/SKILL.md` | Add `zot_flag` parsing + `zot_context` block | Extract `zot_flag` from delegation context, add context injection |

**1 new file** (primary deliverable):
- `extensions/zotero/scripts/zotero-retrieve.sh` — full implementation

**1 existing file** (already stubbed):
- `.claude/extensions/zotero/scripts/zotero-retrieve.sh` — replace stub with implementation

**Script installation**: Zotero scripts are NOT installed to `.claude/scripts/` (only extension scripts for literature are installed). `zotero-retrieve.sh` must either be called via its extension path (`.claude/extensions/zotero/scripts/`) or installed. Given that `literature-retrieve.sh` IS in `.claude/scripts/`, and the skills call `bash .claude/scripts/literature-retrieve.sh`, we should either:
  - Install `zotero-retrieve.sh` to `.claude/scripts/` directly, OR
  - Call it via `.claude/extensions/zotero/scripts/zotero-retrieve.sh`

The cleaner approach (consistent with how other scripts are consumed) is to ensure the script is accessible at `.claude/scripts/zotero-retrieve.sh`. Looking at the install-extension.sh, it creates symlinks for skills and agents but NOT scripts. Scripts must be copied manually. Since this is a meta task implementing the agent system, we should copy (not symlink) to `.claude/scripts/`.

#### 6. On-Demand Conversion Trigger

When an entry has `has_pdf=true` but `has_chunks=false` (no markdown chunks yet), the script should NOT call `zotero-chunk.sh` (that would be slow and potentially disruptive mid-context-injection). Instead, per arch-design Section 5:

> "Elif has_pdf (no chunks yet): Add metadata block: title, authors, year, abstract_snippet. Append note: 'PDF available; run /zotero --convert KEY to generate chunks'"

This is a metadata-only fallback — no on-demand conversion is triggered during retrieval. The architecture design's "on-demand conversion trigger" refers to surfacing the suggestion to the user, not auto-triggering conversion.

#### 7. Chunk-Level Retrieval via literature-search.sh

When `has_chunks=true`, the script should use `literature-search.sh` for chunk-level retrieval:

```bash
chunk_results=$(bash "${SCRIPTS_DIR}/literature-search.sh" "$query_string" 2>/dev/null) || chunk_results=""
```

The `literature-search.sh` script accepts a search query and returns JSON with ranked chunks. The script uses a local `specs/literature/.literature.db` FTS5 database. For chunk retrieval, we need the chunk content files, which are in `specs/literature/{citation_key}/` directories.

Key challenge: `literature-search.sh` returns JSON with `source_path` fields, and the actual content is in `.md` files. The `--read` subcommand reads content by chunk_id. For `zotero-retrieve.sh`, we need to select top-scoring chunks within token budget, then read their content.

**Approach**: Call `literature-search.sh "query_terms" --project "{citation_key}"` (if project filter is supported) to restrict to a specific document, then read chunk files directly from `${chunk_dir}/*.md`.

Looking at `literature-search.sh`, it supports a `--project` filter but this filters by `project_tags`, not by citation key. The simpler approach for zotero context injection: read chunk files directly from `chunk_dir`:

```bash
while IFS= read -r chunk_file; do
  # add chunk content to output until budget exhausted
done < <(find "$chunk_dir" -name "*.md" | sort)
```

This avoids the FTS5 complexity and is consistent with how `literature-retrieve.sh` reads files directly. For relevance ranking within a document, the simple file-order approach (reading chunks sequentially) is acceptable — the entry was already selected by the weighted scoring algorithm.

#### 8. CLAUDE.md Update Required

The current `.claude/CLAUDE.md` contains:
```
**Note**: `--zot` flag wiring to `command-route-skill.sh` is implemented in task 753.
Until then, passing `--zot` has no effect (silently ignored).
```

After implementation, this note must be removed. The extension's `EXTENSION.md` contains the same note (via merge source). The `EXTENSION.md` must also be updated and then the CLAUDE.md regenerated.

#### 9. skill-orchestrate.md: zot_flag Threading

The `skill-orchestrate/SKILL.md` reads `lit_flag` from delegation context and threads it through all sub-dispatches (research, plan, implement phases). The `zot_flag` must be added to the same 12 locations where `lit_flag` appears in that file:

- Stage 0 and Stage 1 delegation context reads
- All research dispatch context objects (both single-task and multi-task modes)
- All plan dispatch context objects
- All implement dispatch context objects

---

### External Resources

- Architecture design document fully specifies the algorithm and wiring — no external documentation needed
- The `jq` scoring pseudocode in arch-design Section 6 is directly implementable as a jq script

---

### Recommendations

#### Implementation Approach

**Phase 1: Implement zotero-retrieve.sh** (primary deliverable)

Write `zotero-retrieve.sh` to `.claude/extensions/zotero/scripts/zotero-retrieve.sh` and copy to `.claude/scripts/zotero-retrieve.sh`. The script should:

1. Graceful exit if `specs/zotero-index.json` missing or entries empty (exit 0, no output)
2. Extract query terms from description (stop-word filtered, length > 3, lowercase, deduplicate)
3. Score entries using the 6-field weighted formula via embedded jq
4. Filter: score >= 4
5. Sort by score descending
6. For each candidate (greedy within TOKEN_BUDGET):
   - If `has_chunks=true` AND `chunk_dir` is a non-empty directory: read chunk files directly
   - If `has_pdf=true` but no chunks: emit metadata block + convert suggestion
   - Else: emit metadata-only block
7. Update `last_retrieved` timestamp in index (best-effort, via jq, non-blocking)
8. Emit `<zotero-context>...</zotero-context>` or empty string

**Phase 2: Wire --zot in command files** (commands/research.md, plan.md, implement.md)

For each command, in Stage 1.5 (flag extraction):
```bash
# Parse --zot flag
zot_flag=false
for arg in $remaining_args; do
  case "$arg" in
    --zot) zot_flag=true ;;
  esac
done
# Remove --zot from focus_prompt
```

Pass as args: `... zot_flag={zot_flag}`.

**Phase 3: Wire zot_context in skills** (skill-researcher, skill-planner, skill-implementer, skill-orchestrate)

After each existing `lit_context` block, add:
```bash
# Zotero context injection (independent of clean_flag and lit_flag)
zot_context=""
zot_flag=$(echo "$delegation_context" | jq -r '.zot_flag // "false"')
if [ "$zot_flag" = "true" ]; then
  zot_context=$(bash .claude/scripts/zotero-retrieve.sh "$description" "$task_type" 2>/dev/null) || zot_context=""
fi
```

In Stage 5 prompt injection:
```
**Zotero Context Injection**: If `zot_context` is non-empty, include after `lit_context`:
{zot_context from Stage 4a -- already wrapped in <zotero-context> tags}
```

**Phase 4: Update EXTENSION.md and CLAUDE.md**

Remove the "not yet implemented" note from `EXTENSION.md`. Regenerate `CLAUDE.md` from merge sources. Also update `commands/research.md`, `plan.md`, `implement.md` option tables to document `--zot`.

#### Key Design Decisions

1. **Script location**: Copy to `.claude/scripts/zotero-retrieve.sh` (not just extension path). Skills use `bash .claude/scripts/...` convention.

2. **Chunk reading**: Read files directly from `chunk_dir` (not via FTS5 search). This is simpler and consistent with `literature-retrieve.sh`'s file-reading approach.

3. **No on-demand conversion**: When `has_pdf=true` but `has_chunks=false`, emit metadata only + suggest convert command. Do NOT auto-trigger `zotero-chunk.sh`.

4. **Token estimation**: Use the `token_count` field from the index entry for budget accounting when chunks exist; use 500-token estimate for metadata-only blocks.

5. **zot_flag NOT in command-route-skill.sh**: Despite the arch-design Section 8 suggesting `command-route-skill.sh` as the wiring point, the actual injection site is the skill SKILL.md files (where `lit_flag` is already handled). `command-route-skill.sh` only routes to skill names.

6. **On-demand conversion trigger**: The arch-design says "if a linked citation lacks markdown chunks, trigger conversion before retrieval." After re-reading, this refers to including a suggestion message (not auto-triggering). Verified: arch-design says "Append note: 'PDF available; run /zotero --convert KEY to generate chunks'", not auto-trigger.

---

## Decisions

- Use direct file reads (not FTS5) for chunk content assembly, consistent with `literature-retrieve.sh` template
- Copy `zotero-retrieve.sh` to both extension scripts dir and `.claude/scripts/` (so skills can call `bash .claude/scripts/zotero-retrieve.sh`)
- Wire `zot_flag` through 7 files (not 1 as arch-design Section 8 implies) — follows actual `lit_flag` pattern
- No auto-conversion during retrieval; surface `run /zotero --convert KEY` suggestion instead

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| `command-route-skill.sh` is NOT the right wiring point (arch-design misleading) | Skills are the actual injection site; verified by examining `lit_flag` pattern in all 4 skill files |
| skill-orchestrate has 12 references to `lit_flag` — easy to miss some | Audit all `lit_flag` occurrences with grep before editing, add `zot_flag` at every location |
| jq scoring using `test($term; "i")` could fail with special-char terms | Add term sanitization (strip non-alphanumeric) before building terms JSON array |
| chunk_dir may be relative or absolute — file resolution must handle both | Resolve relative paths from project root (`$PROJECT_ROOT/$chunk_dir`); always absolutize |
| Token budget overshoot if chunk files don't have accurate token_count | Cap at budget even if a single chunk exceeds budget; skip that chunk rather than truncating it |
| 7-file change scope risks regressions in existing `--lit` behavior | Use exact pattern match to existing `lit_context` blocks; only add new `zot_context` block after |

---

## Context Extension Recommendations

- **Topic**: `--zot` flag composability matrix
- **Gap**: The CLAUDE.md documents the `--lit`/`--clean` interaction matrix but the `--zot` column will be added automatically when EXTENSION.md is updated in Phase 4
- **Recommendation**: After task 753 implementation, the CLAUDE.md Zotero extension section should include the complete 8-row flag interaction matrix from arch-design Section 8

---

## Appendix

### Search Queries Used

- Codebase: grep for `lit_flag`, `LIT_FLAG`, `literature-retrieve`, `LITERATURE_CONTEXT`, `clean_flag`, `--lit`, `--zot`
- Codebase: grep for `zot_flag`, `zotero_flag`, `ZOTERO_CONTEXT`
- File reads: `literature-retrieve.sh`, `command-route-skill.sh`, arch-design summary, `zotero-retrieve.sh` stub
- File reads: `skill-researcher/SKILL.md`, `skill-planner/SKILL.md`, `skill-implementer/SKILL.md`, `skill-orchestrate/SKILL.md`
- File reads: `commands/research.md`, `commands/plan.md`, `commands/implement.md`
- File reads: `literature-search.sh` (for chunk retrieval approach)

### Key File Paths

- Stub to implement: `/home/benjamin/.config/nvim/.claude/extensions/zotero/scripts/zotero-retrieve.sh`
- Target install: `/home/benjamin/.config/nvim/.claude/scripts/zotero-retrieve.sh` (copy)
- Template: `/home/benjamin/.config/nvim/.claude/scripts/literature-retrieve.sh`
- Command files: `/home/benjamin/.config/nvim/.claude/commands/research.md`, `plan.md`, `implement.md`
- Skill files: `/home/benjamin/.config/nvim/.claude/skills/skill-researcher/SKILL.md`, `skill-planner/SKILL.md`, `skill-implementer/SKILL.md`, `skill-orchestrate/SKILL.md`
- Extension docs: `/home/benjamin/.config/nvim/.claude/extensions/zotero/EXTENSION.md`
- CLAUDE.md: `/home/benjamin/.config/nvim/.claude/CLAUDE.md`

### Exact Wiring Locations in skill-orchestrate/SKILL.md

`lit_flag` appears at lines: 36, 59, 205, 232, 256, 285, 944, 945, 966, 968, 995, 998

All 12 locations need a corresponding `zot_flag` addition.
