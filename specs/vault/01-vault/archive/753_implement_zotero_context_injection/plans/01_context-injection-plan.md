# Implementation Plan: Task #753

- **Task**: 753 - Implement Zotero context injection (--zot flag)
- **Status**: [COMPLETED]
- **Effort**: ~2 hours (actual)
- **Dependencies**: Task 752 (zotero-chunk.sh), Task 750 (zotero-read.sh), Task 751 (zotero-search-index.sh)
- **Research Inputs**: specs/753_implement_zotero_context_injection/reports/01_context-injection-research.md
- **Artifacts**: plans/01_context-injection-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Implement the `--zot` flag for `/research`, `/plan`, and `/implement` commands, wiring Zotero-sourced literature context into agent prompts via the per-repo local index (`specs/zotero-index.json`). This is the capstone task in the 5-task Zotero extension chain (749-753). The implementation has two major parts: (1) writing the `zotero-retrieve.sh` scoring/retrieval script that reads the per-repo index, scores entries against query terms, reads chunk files within a token budget, and emits a `<zotero-context>` block; and (2) wiring the `--zot` flag through 7 agent system files (3 command files, 3 skill files, and skill-orchestrate) following the exact pattern established by the existing `--lit`/`literature-retrieve.sh` infrastructure.

### Research Integration

The research report (01_context-injection-research.md) established the following key findings:
- **7 files need changes**, not 1: the `--zot` flag flows through command files (research.md, plan.md, implement.md) as `zot_flag` in delegation context, and is consumed by skill files (skill-researcher, skill-planner, skill-implementer, skill-orchestrate) where the actual `zotero-retrieve.sh` call happens.
- **Scoring algorithm**: title*4 + tags*3 + abstract*2 + keywords*2 + collections*1 + notes*1, threshold >= 4. Directly implementable as jq.
- **Chunk reading**: Direct file reads from `chunk_dir/*.md` (not FTS5). Consistent with `literature-retrieve.sh` approach.
- **No auto-conversion**: When `has_pdf=true` but `has_chunks=false`, emit metadata block + convert suggestion (do not trigger `zotero-chunk.sh`).
- **`command-route-skill.sh` is NOT the injection point** (correcting arch-design Section 8). The actual injection happens in the skill SKILL.md files.
- **skill-orchestrate has 12 `lit_flag` references** that each need a corresponding `zot_flag` addition.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation requested.

## Goals & Non-Goals

**Goals**:
- Implement `zotero-retrieve.sh` with weighted multi-field scoring, chunk-level retrieval, token budgeting, and graceful degradation
- Wire `--zot` flag parsing into `/research`, `/plan`, and `/implement` command files
- Wire `zot_context` injection into skill-researcher, skill-planner, skill-implementer, and skill-orchestrate
- Update EXTENSION.md documentation to remove "not yet implemented" note
- Update `retrieval-flags.md` context file to remove placeholder comments
- Copy `zotero-retrieve.sh` to `.claude/scripts/` for skill consumption
- Ensure composability with `--lit`, `--clean`, `--hard`, `--team`

**Non-Goals**:
- Modifying `command-route-skill.sh` (not the correct injection point)
- Auto-triggering PDF conversion during retrieval (surface suggestion only)
- FTS5-based chunk search (use simple file reads instead)
- Modifying `literature-retrieve.sh` or `literature-search.sh`
- Adding new command-line flags beyond `--zot`

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| jq scoring with `test($term; "i")` fails on special characters in query terms | M | M | Sanitize terms: strip non-alphanumeric before building terms JSON array |
| skill-orchestrate has 12 lit_flag references -- missing one breaks multi-task mode | H | M | Grep-audit all `lit_flag` occurrences before and after editing; add `zot_flag` at every location |
| chunk_dir paths may be relative or absolute -- file resolution inconsistency | M | L | Resolve all paths relative to PROJECT_ROOT; absolutize before reading |
| Token budget overshoot if single chunk exceeds remaining budget | L | M | Skip (do not truncate) chunks that exceed remaining budget; cap at TOKEN_BUDGET |
| 7-file change scope risks regression in existing `--lit` behavior | H | L | Only add new `zot_context` blocks after existing `lit_context` blocks; do not modify lit blocks |
| CLAUDE.md regeneration may not pick up EXTENSION.md changes | M | L | Run merge-sources after EXTENSION.md update to regenerate CLAUDE.md |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Implement zotero-retrieve.sh [COMPLETED]

**Goal**: Create the core retrieval script that scores per-repo index entries against query terms, reads chunk files within a token budget, and emits a `<zotero-context>` block.

**Tasks**:
- [x] Replace the stub in `.claude/extensions/zotero/scripts/zotero-retrieve.sh` with full implementation *(completed)*
- [x] Implement argument parsing: `<description>` and `<task_type>` positional args *(completed)*
- [x] Implement graceful exit: if `specs/zotero-index.json` missing or entries empty, exit 0 with no output *(completed)*
- [x] Implement keyword extraction: tokenize description + task_type, filter stop words (same list as `literature-retrieve.sh`), length > 3, sort + deduplicate, take first 10 *(completed)*
- [x] Implement 6-field weighted scoring via embedded jq: title*4, tags*3, abstract_snippet*2, keywords*2, collections*1, notes_summary*1 *(completed)*
- [x] Implement threshold filter: score >= 4; sort by score descending *(completed)*
- [x] Implement greedy token-budget selection: TOKEN_BUDGET from index `token_budget` field or default 8000, MAX_FILES=10 *(completed)*
- [x] Implement chunk reading path: when `has_chunks=true` and `chunk_dir` is a non-empty directory, read `*.md` files from `chunk_dir` sequentially within remaining budget *(completed)*
- [x] Implement metadata-only fallback: when `has_pdf=true` but no chunks, emit metadata block (title, authors, year, abstract_snippet) + convert suggestion note *(completed)*
- [x] Implement metadata-only path for entries with neither PDF nor chunks *(completed)*
- [x] Implement `last_retrieved` timestamp update (best-effort, non-blocking) *(completed)*
- [x] Emit `<zotero-context>...</zotero-context>` block wrapping all selected content *(completed)*
- [x] Ensure exit 0 always (even on empty results); exit 1 only on fatal JSON parse failure *(completed)*
- [x] Add term sanitization: strip non-alphanumeric characters from query terms before jq `test()` *(completed)*
- [x] Copy completed script to `.claude/scripts/zotero-retrieve.sh` *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/zotero/scripts/zotero-retrieve.sh` - Replace stub with full implementation
- `.claude/scripts/zotero-retrieve.sh` - Copy of the implemented script

**Verification**:
- Script exits 0 with empty output when `specs/zotero-index.json` is missing
- Script exits 0 with empty output when index has no entries
- Script exits 0 with `<zotero-context>` block when entries match query terms
- Script respects TOKEN_BUDGET and MAX_FILES limits
- Script handles entries with chunks, entries with PDF but no chunks, and metadata-only entries
- Script handles special characters in query terms without jq errors
- Both copies (extension path and `.claude/scripts/`) are identical

---

### Phase 2: Wire --zot into command files and skill files [COMPLETED]

**Goal**: Add `--zot` flag parsing to the 3 command files (research.md, plan.md, implement.md) and add `zot_context` injection blocks to the 3 skill files (skill-researcher, skill-planner, skill-implementer).

**Tasks**:
- [x] In `commands/research.md` Stage 1.5: add step 7 "Extract Zot Flag" (after lit flag, before focus prompt extraction) parsing `--zot` -> `zot_flag = true` *(completed)*
- [x] In `commands/research.md` Stage 1.5 step 7 (focus prompt): add `--zot` to the list of flags to remove from remaining args *(completed)*
- [x] In `commands/research.md` Stage 2: add `zot_flag={zot_flag}` to both team and single-agent args strings *(completed)*
- [x] In `commands/research.md` options table: add `--zot` row documenting the flag *(completed)*
- [x] In `commands/plan.md` Stage 1.5: add step 7 "Extract Zot Flag" (after lit flag, before roadmap flag) parsing `--zot` -> `zot_flag = true` *(completed)*
- [x] In `commands/plan.md` Stage 1.5 focus prompt step: add `--zot` to the list of flags to remove *(completed)*
- [x] In `commands/plan.md` Stage 2: add `zot_flag={zot_flag}` to all three args strings (team, single-agent standard, single-agent hard) *(completed)*
- [x] In `commands/plan.md` options table: add `--zot` row documenting the flag *(completed)*
- [x] In `commands/implement.md`: add `zot_flag={ZOT_FLAG}` to both team and single-agent args strings *(completed)*
- [x] In `commands/implement.md` options table: add `--zot` row documenting the flag *(completed)*
- [x] In `skills/skill-researcher/SKILL.md` Stage 4a: add `zot_context` block after existing `lit_context` block, following identical pattern with `zot_flag` and `zotero-retrieve.sh` *(completed)*
- [x] In `skills/skill-researcher/SKILL.md` Stage 4a: add note about `zot_flag` independence from `clean_flag` and `lit_flag` *(completed)*
- [x] In `skills/skill-researcher/SKILL.md` Stage 5: add "Zotero Context Injection" block after the "Literature Context Injection" block *(completed)*
- [x] In `skills/skill-planner/SKILL.md` Stage 4a: add `zot_context` block (same pattern as skill-researcher) *(completed)*
- [x] In `skills/skill-planner/SKILL.md` Stage 5: add "Zotero Context Injection" block *(completed)*
- [x] In `skills/skill-implementer/SKILL.md` Stage 4a: add `zot_context` block (same pattern as skill-researcher) *(completed)*
- [x] In `skills/skill-implementer/SKILL.md` Stage 5: add "Zotero Context Injection" block *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/commands/research.md` - Add `--zot` flag parsing and `zot_flag` in delegation args
- `.claude/commands/plan.md` - Add `--zot` flag parsing and `zot_flag` in delegation args
- `.claude/commands/implement.md` - Add `zot_flag` in delegation args and options table
- `.claude/skills/skill-researcher/SKILL.md` - Add `zot_context` injection in Stage 4a and Stage 5
- `.claude/skills/skill-planner/SKILL.md` - Add `zot_context` injection in Stage 4a and Stage 5
- `.claude/skills/skill-implementer/SKILL.md` - Add `zot_context` injection in Stage 4a and Stage 5

**Verification**:
- Each command file includes `zot_flag` in all skill invocation args strings
- Each skill file has a `zot_context` block that calls `bash .claude/scripts/zotero-retrieve.sh`
- Each skill file injects `zot_context` after `lit_context` in the prompt injection stage
- Existing `lit_context` blocks are unchanged
- `zot_flag` is independent of `clean_flag` and `lit_flag`

---

### Phase 3: Wire --zot through skill-orchestrate [COMPLETED]

**Goal**: Thread `zot_flag` through all dispatch contexts in `skill-orchestrate/SKILL.md`, covering both single-task and multi-task modes (12 injection points matching the existing `lit_flag` pattern).

**Tasks**:
- [x] In Stage 0: add `zot_flag` extraction from delegation context (parallel to existing `lit_flag` extraction at line 36) *(completed)*
- [x] In Stage 1: add `zot_flag` extraction from delegation context (parallel to existing `lit_flag` extraction at line 59) *(completed)*
- [x] In Stage 4 "not_started" state handler: add `"zot_flag": "'$zot_flag'"` to research dispatch context (line ~205) *(completed)*
- [x] In Stage 4 "researched" state handler: add `"zot_flag": "'$zot_flag'"` to plan dispatch context (line ~232) *(completed)*
- [x] In Stage 4 "planned/implementing" state handler: add `"zot_flag": "'$zot_flag'"` to implement dispatch context (line ~256) *(completed)*
- [x] In Stage 4 "partial" state handler (continuation): add `"zot_flag": "'$zot_flag'"` to implement dispatch context (line ~285) *(completed)*
- [x] In Multi-Task Mode research dispatch: add `--arg zot_flag "$zot_flag"` and `"zot_flag": $zot_flag` (lines ~944-945) *(completed)*
- [x] In Multi-Task Mode plan dispatch: add `--arg zot_flag "$zot_flag"` and `"zot_flag": $zot_flag` (lines ~966-968) *(completed)*
- [x] In Multi-Task Mode implement dispatch: add `--arg zot_flag "$zot_flag"` and `"zot_flag": $zot_flag` (lines ~995-998) *(completed)*
- [x] Grep-audit: verify all 12 `lit_flag` locations have corresponding `zot_flag` additions *(completed: lit_flag=12, zot_flag=12)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Add `zot_flag` at all 12 locations where `lit_flag` appears

**Verification**:
- `grep -c 'zot_flag' skill-orchestrate/SKILL.md` returns count equal to `grep -c 'lit_flag' skill-orchestrate/SKILL.md`
- All dispatch context JSON objects include both `lit_flag` and `zot_flag`
- Both single-task and multi-task modes thread `zot_flag` through all dispatches

---

### Phase 4: Update documentation and final verification [COMPLETED]

**Goal**: Update EXTENSION.md to remove the "not yet implemented" note, update `retrieval-flags.md` to remove placeholder comments, regenerate CLAUDE.md from merge sources, and perform end-to-end verification.

**Tasks**:
- [x] Update `.claude/extensions/zotero/EXTENSION.md`: remove or update any "not yet implemented" note related to `--zot` wiring *(completed)*
- [x] Update `.claude/extensions/zotero/context/project/zotero/patterns/retrieval-flags.md`: remove `<!-- Content populated in task 753 -->` and `<!-- Full coexistence documentation populated in task 753 -->` placeholder comments *(completed)*
- [x] Update `.claude/extensions/zotero/scripts/zotero-retrieve.sh` header: change "implemented in task 753" to "implemented" (remove future-tense references) *(completed)*
- [x] Regenerate `.claude/CLAUDE.md` from merge sources (removes the "task 753" note at line 703) *(completed)*
- [x] Run comprehensive grep audit: `grep -rn 'task 753' .claude/extensions/zotero/` to find remaining references and update them *(completed: no remaining task 753 references in zotero extension)*
- [x] Verify all 8 modified/created files are syntactically correct (no broken markdown, valid bash) *(completed)*
- [x] Verify `zotero-retrieve.sh` is accessible at both `.claude/extensions/zotero/scripts/` and `.claude/scripts/` *(completed: both 310-line files exist and are executable)*

**Timing**: 45 minutes

**Depends on**: 2, 3

**Files to modify**:
- `.claude/extensions/zotero/EXTENSION.md` - Remove "not yet implemented" note
- `.claude/extensions/zotero/context/project/zotero/patterns/retrieval-flags.md` - Remove placeholder comments
- `.claude/extensions/zotero/scripts/zotero-retrieve.sh` - Update header comments
- `.claude/CLAUDE.md` - Regenerate from merge sources

**Verification**:
- `grep -rn 'not yet implemented.*753' .claude/extensions/zotero/` returns no results (only task 751/752 references remain)
- `grep 'task 753' .claude/CLAUDE.md` returns no results
- `.claude/scripts/zotero-retrieve.sh` exists and is executable
- The `--zot` flag is documented in command option tables
- `retrieval-flags.md` has no placeholder comments

---

## Testing & Validation

- [ ] `bash .claude/scripts/zotero-retrieve.sh "test query" "meta"` exits 0 with empty output when `specs/zotero-index.json` is absent
- [ ] Create a minimal `specs/zotero-index.json` with test entries and verify scoring produces correct rankings
- [ ] Verify `--zot` flag is parsed in `commands/research.md` by tracing `zot_flag` through delegation args
- [ ] Verify `--zot` flag is parsed in `commands/plan.md` by tracing `zot_flag` through delegation args
- [ ] Verify `--zot` flag is parsed in `commands/implement.md` by tracing `zot_flag` through delegation args
- [ ] Verify `zot_context` injection block exists in all 3 skill files after `lit_context` block
- [ ] Verify `zot_flag` appears at same count as `lit_flag` in `skill-orchestrate/SKILL.md`
- [ ] Verify no regressions: `lit_flag` / `lit_context` blocks unchanged in all skill files
- [ ] Verify CLAUDE.md no longer contains "task 753" reference

## Artifacts & Outputs

- `specs/753_implement_zotero_context_injection/plans/01_context-injection-plan.md` (this file)
- `.claude/extensions/zotero/scripts/zotero-retrieve.sh` (full implementation)
- `.claude/scripts/zotero-retrieve.sh` (copy for skill consumption)
- `.claude/commands/research.md` (updated with --zot flag)
- `.claude/commands/plan.md` (updated with --zot flag)
- `.claude/commands/implement.md` (updated with --zot flag)
- `.claude/skills/skill-researcher/SKILL.md` (updated with zot_context injection)
- `.claude/skills/skill-planner/SKILL.md` (updated with zot_context injection)
- `.claude/skills/skill-implementer/SKILL.md` (updated with zot_context injection)
- `.claude/skills/skill-orchestrate/SKILL.md` (updated with zot_flag threading)
- `.claude/extensions/zotero/EXTENSION.md` (documentation updated)
- `.claude/extensions/zotero/context/project/zotero/patterns/retrieval-flags.md` (placeholders removed)
- `.claude/CLAUDE.md` (regenerated)

## Rollback/Contingency

All changes are additive -- existing `--lit` behavior is not modified. If issues arise:
1. Revert the 7 wiring files to their pre-task-753 state (git checkout)
2. Replace `zotero-retrieve.sh` with the original stub (exit 2 with "not yet implemented" message)
3. The `--zot` flag will silently have no effect (scripts return empty, skills inject nothing)
4. No other extensions or core functionality is affected
