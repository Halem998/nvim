# Implementation Plan: Task #689

- **Task**: 689 - Add --lit context injection to skill preflight (researcher, planner, implementer)
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: Task 688 (COMPLETED - LIT_FLAG exported by parse-command-args.sh)
- **Research Inputs**: specs/689_lit_context_injection_skill_preflight/reports/01_lit-context-injection.md
- **Artifacts**: plans/01_lit-context-injection-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add literature context injection to the skill layer, mirroring the existing memory-retrieve pattern. When `lit_flag` is true, the three core skills (researcher, planner, implementer) invoke a new `literature-retrieve.sh` script that reads files from `specs/literature/` and outputs a `<literature-context>` block. The block is injected into the agent delegation prompt after memory context and before task instructions. The skill-orchestrate state machine is also updated to thread `lit_flag` through all dispatch contexts. All changes are synced to the core extension copies.

### Research Integration

The research report (01_lit-context-injection.md) provided:
- Exact line numbers for Stage 4a memory retrieval in all three skills (researcher L124-143, planner L142-161, implementer L139-158)
- A complete script skeleton for `literature-retrieve.sh` with TOKEN_BUDGET=4000 and "read-all-within-budget" approach
- Identified all four dispatch context locations in skill-orchestrate (lines 203, 230, 253, 279) plus multi-task dispatch at lines 911-919, 936-937, 962-968
- Confirmed core extension copies are byte-identical to primary skill files
- Key decision: `lit_flag` is independent of `clean_flag` -- `--clean --lit` works (clean suppresses memory, lit still injects literature)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly reference this feature.

## Goals & Non-Goals

**Goals**:
- Create `literature-retrieve.sh` script that reads `specs/literature/` files within a token budget and outputs a `<literature-context>` block
- Add Stage 4a literature retrieval to skill-researcher, skill-planner, and skill-implementer, gated on `lit_flag`
- Thread `lit_flag` through skill-orchestrate Stage 1 extraction and all dispatch contexts (single-task and multi-task)
- Sync all changes to `.claude/extensions/core/` copies
- Validate end-to-end by dry-run testing the script

**Non-Goals**:
- Command-layer changes (research.md, plan.md, implement.md, orchestrate.md) -- covered by Task 690
- Adding `--lit` to parse-command-args.sh -- already done by Task 688
- Creating a `specs/literature/` directory or populating it with content
- Adding hard-mode variants (skill-researcher-hard, etc.) -- follow-on task if needed
- Adding team-mode variants (skill-team-research, etc.) -- follow-on task if needed

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Core extension copies drift from primary skills | M | M | Phase 3 uses `cp` and `diff` verification |
| Large literature files bloat agent context | M | L | TOKEN_BUDGET=4000 cap with truncation notice in script |
| Skill-orchestrate dispatch contexts are pseudocode (not runnable bash) | L | L | Changes are documentation-level edits matching existing patterns |
| `lit_flag` not threaded from commands yet (Task 690) | L | H | Expected -- skills will receive `lit_flag` as empty/false until commands pass it; graceful no-op |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Create literature-retrieve.sh script [COMPLETED]

**Goal**: Create the `literature-retrieve.sh` script following the memory-retrieve.sh pattern, then verify it runs correctly.

**Tasks**:
- [x] Create `.claude/scripts/literature-retrieve.sh` with the following behavior:
  - Accept args: `description` (required), `task_type` (required)
  - Check `specs/literature/` exists; exit 1 if not
  - Find all `.md` and `.txt` files (maxdepth 1), sorted
  - Read files within TOKEN_BUDGET=4000 (words x 1.3 estimate), MAX_FILES=10
  - Output `<literature-context>` wrapped block with file contents under `### filename` headers
  - Truncation notice when budget exceeded
  - Exit 0 on success (files found), exit 1 on no content *(completed)*
- [x] Make script executable: `chmod +x .claude/scripts/literature-retrieve.sh` *(completed)*
- [x] Test with empty/missing directory (should exit 1 silently) *(completed: exits 1 with no output)*
- [x] Test with a temporary test file in `specs/literature/` (should output formatted block) *(completed: correct <literature-context> output, test dir removed)*
- [x] Create core extension copy: `cp .claude/scripts/literature-retrieve.sh .claude/extensions/core/scripts/literature-retrieve.sh` *(completed: diff verified byte-identical)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/literature-retrieve.sh` - CREATE new script
- `.claude/extensions/core/scripts/literature-retrieve.sh` - CREATE copy

**Verification**:
- Script exits 1 when `specs/literature/` does not exist
- Script exits 0 and outputs `<literature-context>` block when test files are present
- Script handles files exceeding TOKEN_BUDGET with truncation notice
- Core extension copy is byte-identical to primary (`diff` returns 0)

---

### Phase 2: Add literature injection to skill-researcher, skill-planner, skill-implementer [COMPLETED]

**Goal**: Add Stage 4a literature retrieval and Stage 5 prompt injection to all three skills, gated on `lit_flag`.

**Tasks**:
- [x] **skill-researcher/SKILL.md**: After the existing Stage 4a memory retrieval block (after line 143), add literature retrieval:
  - Add `lit_context=""` initialization
  - Add `if [ "$lit_flag" = "true" ]` block calling `literature-retrieve.sh`
  - In Stage 5 prompt injection section (after the memory context injection instructions around line 225), add parallel instructions for `lit_context` injection placed AFTER memory context and BEFORE task instructions
  - Clarify that `lit_flag` is independent of `clean_flag` (not suppressed by `--clean`) *(completed)*
- [x] **skill-planner/SKILL.md**: Same pattern as researcher:
  - After Stage 4a memory block (after line 161), add literature retrieval
  - In Stage 5 prompt injection (after line 254), add `lit_context` injection instructions *(completed)*
- [x] **skill-implementer/SKILL.md**: Same pattern as researcher:
  - After Stage 4a memory block (after line 158), add literature retrieval
  - In Stage 5 prompt injection (after line 241), add `lit_context` injection instructions *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Add Stage 4a lit retrieval + Stage 5 injection (~15 lines)
- `.claude/skills/skill-planner/SKILL.md` - Same pattern (~15 lines)
- `.claude/skills/skill-implementer/SKILL.md` - Same pattern (~15 lines)

**Verification**:
- Each skill's Stage 4a has both memory and literature retrieval blocks
- Literature retrieval is gated on `lit_flag = "true"` (NOT on `clean_flag`)
- Stage 5 injection instructions place `<literature-context>` AFTER `<memory-context>` and BEFORE task instructions
- Empty `<literature-context>` block is NOT injected when `lit_context` is empty

---

### Phase 3: Thread lit_flag in skill-orchestrate + sync core extension copies [COMPLETED]

**Goal**: Thread `lit_flag` through skill-orchestrate's extraction and all dispatch contexts, then sync all changes to core extension copies.

**Tasks**:
- [x] **skill-orchestrate/SKILL.md Stage 1**: After the `focus_prompt` extraction (line 57), add `lit_flag` extraction from delegation context:
  ```
  lit_flag=$(echo "$delegation_context" | jq -r '.lit_flag // "false"')
  ```
  *(completed: added to both Stage 0 and Stage 1 extraction blocks)*
- [x] **skill-orchestrate/SKILL.md Stage 4 single-task dispatches**: Add `"lit_flag": "$lit_flag"` to all four dispatch context JSONs:
  - `not_started` state research dispatch (line 203)
  - `researched` state plan dispatch (line 230)
  - `planned`/`implementing` state implement dispatch (line 253)
  - `partial` state continuation dispatch (line 279) *(completed)*
- [x] **skill-orchestrate/SKILL.md Stage MT-4 multi-task dispatches**: Add `"lit_flag": "$lit_flag"` to dispatch contexts for:
  - Research tasks dispatch (lines 911-919)
  - Plan tasks dispatch (lines 936-937)
  - Implement tasks dispatch (lines 962-968) *(completed: used jq --arg lit_flag pattern)*
- [x] **Sync to core extension copies**: Copy all four modified skill files to extension directory:
  - `cp .claude/skills/skill-researcher/SKILL.md .claude/extensions/core/skills/skill-researcher/SKILL.md`
  - `cp .claude/skills/skill-planner/SKILL.md .claude/extensions/core/skills/skill-planner/SKILL.md`
  - `cp .claude/skills/skill-implementer/SKILL.md .claude/extensions/core/skills/skill-implementer/SKILL.md`
  - `cp .claude/skills/skill-orchestrate/SKILL.md .claude/extensions/core/skills/skill-orchestrate/SKILL.md` *(completed)*
- [x] **Verify sync**: Run `diff` on all four pairs to confirm byte-identical copies *(completed: all 4 pairs identical)*

**Timing**: 45 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-orchestrate/SKILL.md` - Stage 1 extraction + 7 dispatch contexts (~20 lines)
- `.claude/extensions/core/skills/skill-researcher/SKILL.md` - Sync copy
- `.claude/extensions/core/skills/skill-planner/SKILL.md` - Sync copy
- `.claude/extensions/core/skills/skill-implementer/SKILL.md` - Sync copy
- `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` - Sync copy

**Verification**:
- `lit_flag` extracted in Stage 1 with `// "false"` default
- All 7 dispatch contexts include `"lit_flag"` field
- All 4 core extension copies are byte-identical to primaries (verified by `diff`)
- No regressions in existing `clean_flag` or `memory_context` behavior

## Testing & Validation

- [ ] `literature-retrieve.sh` exits 1 when `specs/literature/` does not exist
- [ ] `literature-retrieve.sh` exits 0 and outputs valid `<literature-context>` block with test files
- [ ] Token budget truncation works correctly with oversized files
- [ ] Each skill SKILL.md has Stage 4a with both memory and literature retrieval
- [ ] Literature retrieval is gated on `lit_flag`, NOT on `clean_flag`
- [ ] Stage 5 injection places `<literature-context>` after `<memory-context>`, before task instructions
- [ ] skill-orchestrate extracts `lit_flag` in Stage 1 with safe default
- [ ] All 7 dispatch contexts in skill-orchestrate include `lit_flag`
- [ ] All 5 core extension copies (4 skills + 1 script) are byte-identical to primaries

## Artifacts & Outputs

- `.claude/scripts/literature-retrieve.sh` - New script
- `.claude/skills/skill-researcher/SKILL.md` - Modified
- `.claude/skills/skill-planner/SKILL.md` - Modified
- `.claude/skills/skill-implementer/SKILL.md` - Modified
- `.claude/skills/skill-orchestrate/SKILL.md` - Modified
- `.claude/extensions/core/scripts/literature-retrieve.sh` - New script (copy)
- `.claude/extensions/core/skills/skill-researcher/SKILL.md` - Synced copy
- `.claude/extensions/core/skills/skill-planner/SKILL.md` - Synced copy
- `.claude/extensions/core/skills/skill-implementer/SKILL.md` - Synced copy
- `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` - Synced copy

## Rollback/Contingency

All changes are to `.claude/` infrastructure files tracked in git. Rollback via:
```bash
git checkout HEAD -- .claude/scripts/literature-retrieve.sh .claude/skills/skill-{researcher,planner,implementer,orchestrate}/SKILL.md .claude/extensions/core/
```
If `literature-retrieve.sh` was newly created, remove it:
```bash
rm -f .claude/scripts/literature-retrieve.sh .claude/extensions/core/scripts/literature-retrieve.sh
```
