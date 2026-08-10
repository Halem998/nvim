# Research Report: Task #394

**Task**: 394 - Remove language-to-task_type backward compatibility shim
**Started**: 2026-04-13T18:30:00Z
**Completed**: 2026-04-13T18:45:00Z
**Effort**: 15 minutes
**Dependencies**: None (task 393 completed, no legacy tasks remain)
**Sources/Inputs**:
- Codebase search (Grep, Glob) across `.claude/` directory
- `specs/state.json` (active projects)
- `specs/archive/state.json` (archived projects)
- Task 393 implementation summary
**Artifacts**:
- specs/394_remove_language_to_task_type_compat_shim/reports/01_remove-compat-shim.md
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The backward compatibility shim (`.task_type // .language // "general"`) exists in 19 core files (commands and skills)
- Zero active tasks in state.json use the old `language` field -- all 6 active projects have `task_type`
- 18 extension skills still read `.language` directly (not via shim) and need updating to `.task_type`
- 11 extension commands read `.language` bare and need updating to `.task_type`
- The archive state.json contains ~200 entries with old `language` field but these are never read by active commands
- It is safe to remove the shim now

## Context & Scope

Task 393 renamed the `language` routing field to `task_type` across the entire agent system. As a safety measure, a backward compatibility shim was added: `.task_type // .language // "general"`. This shim allows old tasks that still have a `language` field (but no `task_type`) to continue working. Task 394 was created to remove this shim once all legacy tasks are archived.

## Findings

### Category 1: Core files with `.task_type // .language // "general"` shim (19 files)

These files use the full fallback chain and need the `// .language` portion removed:

**Commands (6 files):**
1. `.claude/commands/implement.md` (line 361)
2. `.claude/commands/plan.md` (line 318)
3. `.claude/commands/research.md` (lines 262, 319)
4. `.claude/commands/spawn.md` (line 73)
5. `.claude/commands/task.md` (line 337)
6. `.claude/commands/todo.md` (lines 160, 176, 1277, 1279)

**Core Skills (8 files):**
1. `.claude/skills/skill-implementer/SKILL.md` (line 54)
2. `.claude/skills/skill-planner/SKILL.md` (line 59)
3. `.claude/skills/skill-researcher/SKILL.md` (line 58)
4. `.claude/skills/skill-reviser/SKILL.md` (line 54)
5. `.claude/skills/skill-spawn/SKILL.md` (line 58)
6. `.claude/skills/skill-team-implement/SKILL.md` (line 65)
7. `.claude/skills/skill-team-plan/SKILL.md` (line 63)
8. `.claude/skills/skill-team-research/SKILL.md` (line 65)

**Extension Skills with shim pattern (5 files):**
1. `.claude/extensions/formal/skills/skill-logic-research/SKILL.md` (line 49)
2. `.claude/extensions/lean/skills/skill-lean-implementation/SKILL.md` (line 44)
3. `.claude/extensions/lean/skills/skill-lean-research/SKILL.md` (line 43)
4. `.claude/extensions/nix/skills/skill-nix-implementation/SKILL.md` (line 102)
5. `.claude/extensions/web/skills/skill-web-implementation/SKILL.md` (line 102)

**Change**: Replace `.task_type // .language // "general"` with `.task_type // "general"`
**Change for todo.md**: Replace `(.task_type // .language)` with `.task_type`

### Category 2: Extension skills reading `.language` directly (18 files)

These were NOT updated during task 393 -- they still read `.language` as a variable name. They need to be updated to read `.task_type` instead:

**Founder extension (10 files):**
- `skill-analyze`, `skill-deck-research`, `skill-finance`, `skill-financial-analysis`, `skill-legal`, `skill-market`, `skill-meeting`, `skill-project`, `skill-spreadsheet`, `skill-strategy`
- Pattern: `language=$(echo "$task_data" | jq -r '.language // "founder"')`
- Change to: `task_type=$(echo "$task_data" | jq -r '.task_type // "founder"')`

**Present extension (4 files):**
- `skill-budget`, `skill-funds`, `skill-grant`, `skill-timeline`
- Pattern: `language=$(echo "$task_data" | jq -r '.language // "present"')`
- Change to: `task_type=$(echo "$task_data" | jq -r '.task_type // "present"')`

**Other extensions (4 files):**
- `nvim/skill-neovim-research`, `nvim/skill-neovim-implementation` -- reads `.language // "neovim"`
- `nix/skill-nix-research` -- reads `.language // "nix"`
- `web/skill-web-research` -- reads `.language // "web"`

**Note**: These also need downstream variable references updated (`$language` to `$task_type`).

### Category 3: Extension commands reading `.language` bare (11 files)

**Founder commands (9 files):**
- `analyze.md`, `deck.md`, `finance.md`, `legal.md`, `market.md`, `meeting.md`, `project.md`, `sheet.md`, `strategy.md`
- Pattern: `task_lang=$(echo "$task_data" | jq -r '.language')`
- Change to: `task_lang=$(echo "$task_data" | jq -r '.task_type')`

**Present commands (2 files):**
- `budget.md`, `funds.md`
- Same pattern as founder commands

### Category 4: Archive state.json (no action needed)

`specs/archive/state.json` contains ~200 entries with old `language` field. These are archived completed tasks and are never read by any active command. No changes needed.

### Category 5: Documentation prose references (no action needed)

Two context files mention `languages` in prose:
- `.claude/context/patterns/context-discovery.md` (line 272) -- mentions "languages" in English description
- `.claude/context/README.md` (line 189) -- shows old `load_when.languages` example

The README example should be updated to show `task_types` instead. The context-discovery.md reference is ambiguous English prose and could be left as-is or clarified.

### Safety Assessment

- **Active state.json**: 0 out of 6 active projects use `language` field. All have `task_type`.
- **Archive state.json**: Contains old `language` entries but is read-only archive data.
- **Task creation**: `/task` command already creates tasks with `task_type` only.
- **Conclusion**: It is safe to remove the shim. No active tasks will break.

## Decisions

- The shim can be removed now -- no active legacy tasks remain
- Extension skills that read `.language` directly represent an incomplete migration from task 393 and should be fixed as part of this task
- Archive state.json should NOT be modified (it is historical record)
- The two documentation prose references should be updated for accuracy

## Recommendations

### Implementation approach

**Phase 1**: Remove shim from core files (19 files)
- Replace `.task_type // .language // "general"` with `.task_type // "general"`
- Replace `(.task_type // .language)` with `.task_type` in todo.md

**Phase 2**: Update extension skills reading `.language` directly (18 files)
- Replace `.language` field reads with `.task_type`
- Update variable names from `$language` to `$task_type` where used downstream

**Phase 3**: Update extension commands reading `.language` bare (11 files)
- Replace `.language` reads with `.task_type`

**Phase 4**: Update documentation prose (2 files)
- Fix the stale `load_when.languages` example in context/README.md

Total: 50 files to modify across 4 phases.

## Risks & Mitigations

- **Risk**: Extension skills may reference `$language` variable downstream after extraction
  - **Mitigation**: Search for `$language` usage in each file and update all references
- **Risk**: Other projects sharing this `.claude/` config may have old-format state.json
  - **Mitigation**: Verified -- `.opencode/` state files have no `language` entries; only archive has them

## Appendix

### Search queries used
- `grep -r '.language' .claude/` -- found all references
- `grep '"language"' specs/state.json` -- confirmed no active tasks use old field
- `grep '"language"' specs/archive/state.json` -- confirmed archive has old entries (expected)
- `grep 'load_when.*languages' .claude/context/` -- found 2 prose references
- `grep '"languages"' .claude/context/index.json` -- confirmed index.json fully migrated

### File counts by category
| Category | Files | Change type |
|----------|-------|-------------|
| Core shim removal | 19 | `.task_type // .language // "general"` -> `.task_type // "general"` |
| Extension skill `.language` reads | 18 | `.language` -> `.task_type` + variable rename |
| Extension command `.language` reads | 11 | `.language` -> `.task_type` |
| Documentation prose | 2 | Update examples |
| **Total** | **50** | |
