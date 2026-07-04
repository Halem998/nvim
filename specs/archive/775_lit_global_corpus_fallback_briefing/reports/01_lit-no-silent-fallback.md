# Research Report: Task 775 — `--lit` No-Silent-Fallback + Global-Corpus Briefing

## Scope investigated
- `.claude/scripts/literature-briefing.sh` (203 lines; identical to `.claude/extensions/literature/scripts/literature-briefing.sh`)
- `.claude/scripts/literature-search.sh` (689 lines; identical copy in `extensions/literature/scripts/`)
- `.claude/scripts/literature-retrieve.sh` (deprecated, 217 lines; canonical in `extensions/core/scripts/`)
- `.claude/scripts/literature-create-setup-task.sh` (102 lines)
- Stage 4a blocks in all six skills (`skill-researcher`, `skill-researcher-hard`, `skill-planner`, `skill-planner-hard`, `skill-implementer`, `skill-implementer-hard`)
- CLAUDE.md source-of-truth: `.claude/extensions/core/merge-sources/claudemd.md` ("Literature Mode" section, line ~313)
- `.claude/skills/skill-orchestrate/SKILL.md` (threading of `lit_flag`/`orchestrator_mode`)
- Global corpus verified live: `~/Projects/Literature/index.json` has 222 entries with `project_tags` field present; `.literature.db` exists with FTS5 schema (`chunks_data`/`chunks_fts`/`chunk_relations`, BM25 weights title=10/keywords=5/summary=3/content=1)
- Transcript `.claude/output/lit.md` confirms the G1 failure mode narrative

## G1 — Hard gate + silent empty exit (literature-briefing.sh)
`literature-briefing.sh` takes **no arguments** (line 4). Behavior:
- Line 39-41: `if [ ! -f "$SUB_INDEX" ]; then exit 0; fi` — silent, empty stdout, no stderr
- Line 44-47: if global index missing, warns to stderr but still `exit 0` empty
- Lines 17-22 document that interactive detection is "handled UPSTREAM in the Stage 4a block"

The script is fine as a library function (silent/empty with no query = the per-repo curated-index path) but per requirement 1 must gain a second mode.

## G2 — No global-corpus option
No code path currently queries the global corpus for a one-off briefing. `literature-search.sh` already does two-tier search (local `specs/literature/.literature.db` then global `$LITERATURE_DIR/.literature.db`, BM25-merged, local wins duplicates — `find_databases()` line 64-72, `do_search()` line 131-352) and supports project-tag filtering via `--project <name>` (`get_project_doc_ids()` line 35-53, pre-scanned line 628-641). This is the machinery option (b) needs, but nothing builds a `<literature-briefing>`-shaped block from `do_search` JSON — that glue does not exist.

## Requirement (1): literature-briefing.sh accepts query + global-corpus mode
- Current: zero args, reads `specs/literature-index.json` unconditionally
- Change (canonical `.claude/extensions/literature/scripts/literature-briefing.sh`, mirrored to `.claude/scripts/literature-briefing.sh`):
  - Add mode dispatch: `literature-briefing.sh [--global "<query>" [--top-n N]]` vs existing no-arg per-repo mode
  - Global mode: call `literature-search.sh "<query>"` (optionally `--project "$(basename "$PROJECT_ROOT")"` first, falling back to unfiltered — reuse existing fallback at lines 269-349) to get ranked JSON chunk results; take top-N (constant `GLOBAL_TOP_N=8`); build entries from JSON fields per chunk (`chunk_id`, `doc_id`, `section_path`, `title`, `summary`, `token_count`, `snippet`). Chunk/segment granularity (not parent-child aggregation used by sub-index path lines 84-138) — intentional, global mode has no curated doc_id list
  - Pointer resolution: instruct agent to fetch via `literature-search.sh --read <chunk_id>` (simpler, avoids duplicating path-resolution logic — RECOMMENDED) rather than resolving absolute paths
  - Keep no-arg per-repo path unchanged (still exits 0 empty on missing sub-index); global mode strictly additive
  - Reuse `<literature-briefing>` wrapper tag for both modes (callers don't special-case); header should indicate provenance, e.g. `## Available Literature — Global Corpus Search Results for: "<query>" (${N} segment(s))`

## Requirement (2): wire interactive prompt into Stage 4a, reconcile 3-option flow
Stage 4a is structurally identical across all six skills:

| Skill | Stage 4a starts | ends (approx) |
|---|---|---|
| skill-researcher | line 146 | ~255 |
| skill-researcher-hard | line 121 | ~217 |
| skill-planner | line 157 | ~267 |
| skill-planner-hard | line 129 | ~226 |
| skill-implementer | line 139 | ~249 |
| skill-implementer-hard | line 144 | ~236 |

Each block shape (canonical template = skill-researcher lines 167-253):
1. `lit_context=""` init
2. If `lit_flag=true` and `specs/literature-index.json` missing:
   - global index missing too → stderr note, continue empty (acceptable sub-branch)
   - else → pseudocode `AskUserQuestion` with **3 options**: Skip / Create setup task / Create task and run now (lines 181-215)
3. "Stage 4a-fork" sub-section (lines 218-240): fork agent populates sub-index for option 3
4. Final unconditional block (lines 242-251): calls `literature-briefing.sh` (no-arg) if sub-index exists

**Problems / fixes**:
- Reframe to two live outcomes: **(a) Create curation task** (build per-repo sub-index for future runs; optionally fold in old option-3 inline-fork-populate-now as a modifier so the current run benefits) vs **(b) Use global corpus now** (new — call `literature-briefing.sh --global "<task description>"`). Keep an explicit **Skip this run** as a clearly-chosen (non-silent) third option. User directive: "I don't like fallbacks which are silent" — an explicit user-chosen skip is fine; the bug was code choosing nothing by default
- Six identical blocks → one edit pattern applied 6×. **DESIGN RECOMMENDATION**: factor shared logic into a single `literature-lit-flag-resolve.sh` called from all six Stage 4a blocks to prevent future drift (the current 6× duplication is what let the design go stale)
- The Stage 4a-fork machinery (fork agent reading `~/Projects/Literature/index.json` + `specs/state.json`, writing `specs/literature-index.json`) is reusable as-is for the "Create curation task" branch

## Requirement (3): "How to Use" footer on both briefing paths
`literature-briefing.sh` lines 187-199 (heredoc `FOOTER`) already produce the footer unconditionally at end of per-repo output (Read chunk files via absolute path; run `literature-search.sh "<query>"`; `--toc`; read selectively). Fix: structure the script so both modes share ONE exit point that appends this footer (no separate early `cat`+`exit` for global mode). Guarantees no branch produces a briefing without the footer.

## Requirement (4): DESIGN QUESTION — autonomous default (/orchestrate)
- `lit_flag` is a top-level orchestrator flag (skill-orchestrate SKILL.md line 33, default "false"), threaded unchanged into every dispatch context (lines 187, 216, 237, 265; Agent invocations 640/644/649)
- `orchestrator_mode` is passed in the SAME context object (`false` for research, `true` for plan/implement) BUT grep shows **zero references to `orchestrator_mode`** in skill-researcher/skill-planner/skill-implementer — Stage 4a never checks it. Today `/orchestrate N --lit` hitting a missing sub-index → undefined behavior (pseudocode says call AskUserQuestion with no no-human fallback)
- **Resolution options for /plan**:
  - Detect autonomy via existing `orchestrator_mode` field (no new plumbing to detect)
  - Default candidates: (i) default to "Use global corpus now" with a VISIBLE logged notice (transcript/stderr + task artifact log), or (ii) "create-and-defer" via `literature-create-setup-task.sh` (exists, silent-safe, returns task number) + empty-but-logged briefing
  - RECOMMENDATION: (i) is more useful (agent gets literature this run) and still non-silent; global corpus is directly queryable with zero setup — but this trade-off is deferred to /plan
  - Hook point: add `orchestrator_mode == true` branch inside the Stage 4a conditional (all six files) that bypasses AskUserQuestion and takes the deterministic default, logging its choice

## Supporting facts for the plan phase
- `literature-search.sh --project <name>` exists, filters global index by `project_tags` (lines 44-53, 628-641) — ready-made scoping to current repo
- `literature-search.sh` has a "zero-filtered-results → retry unfiltered" fallback (lines 269-349) — reuse in global-briefing mode
- `literature-create-setup-task.sh` (102 lines) fully functional, reusable unchanged for the "Create curation task" branch (inserts meta task into state.json, regenerates TODO.md)
- `literature-retrieve.sh` DEPRECATED (line 2, superseded by literature-briefing.sh per task 758), not in the six skills' call path — safe to ignore
- CLAUDE.md "Interactive Sub-Index Setup Detection" (3-option flow) lives in `.claude/extensions/core/merge-sources/claudemd.md` lines 328-350 (single source regenerating `.claude/CLAUDE.md`'s Literature Mode section) — must be rewritten for the new two-option (+visible-skip) flow and autonomous default once decided (overlaps with task 776 requirement 2)
