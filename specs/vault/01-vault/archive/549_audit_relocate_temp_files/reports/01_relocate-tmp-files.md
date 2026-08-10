# Research Report: Task #549

**Task**: 549 - audit_relocate_temp_files
**Started**: 2026-05-07T00:00:00Z
**Completed**: 2026-05-07T00:00:00Z
**Effort**: M
**Dependencies**: None
**Sources/Inputs**:
- Codebase: grep on .opencode/ for `/tmp/` pattern
- Codebase: glob on .opencode/ for file discovery
- Comparison: core/ vs project/ context directories
- File inspection: read of affected files
**Artifacts**:
- specs/549_audit_relocate_temp_files/reports/01_relocate-tmp-files.md
**Standards**: report-format.md, return-metadata-file.md

## Executive Summary

- Found **~124 unique files** with `/tmp/` substring under `.opencode/`, but the **vast majority are already using `specs/tmp/`** correctly
- Identified **14 files with actual `/tmp/` references** (not `specs/tmp/`) that need relocation, totaling approximately 50 individual references
- The split falls into three categories: **extension SKILL.md files** (8 files, ~26 refs), **core context patterns** (2 files, ~9 refs), and **project context processes** (3 files, ~7 refs), plus one **documentation guide** (6 refs)
- The `specs/tmp/` directory already exists and contains prior files (`claude-tts-last-notify`, `claude-tts-notify.log`), confirming the migration path is viable
- All affected references follow the same pattern: temporary state.json manipulation or one-off temp files -- safe to change to `specs/tmp/`

## Context & Scope

Task 549 involves auditing all `/tmp/` file path references under `.opencode/` (agents, skills, context, scripts, rules, docs) and replacing them with `specs/tmp/` paths. The goal is to keep temporary files within the project root to avoid `external_directory: "ask"` permission prompts from OpenCode.

**Constraints**:
- Must not break existing workflows that use these temp paths
- Should distinguish between historical/documentation references and active code
- Extension skill files and core skill file counterparts must remain functional after migration

## Findings

### Category A: Extension SKILL.md Files (8 files, ~26 refs)

These extension skill files use `/tmp/state.json` for temporary state updates during implementation postflight workflows. The pattern is identical across all: `specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json`. All should be changed to `specs/tmp/state.json`.

| # | File | Refs | Pattern |
|---|------|------|---------|
| A1 | `.opencode/extensions/web/skills/skill-web-implementation/SKILL.md` | 7 | `/tmp/state.json` |
| A2 | `.opencode/extensions/web/skills/skill-web-research/SKILL.md` | 3 | `/tmp/state.json` |
| A3 | `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md` | 3 | `/tmp/state.json` |
| A4 | `.opencode/extensions/lean/skills/skill-lean-research/SKILL.md` | 3 | `/tmp/state.json` |
| A5 | `.opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md` | 5 | `/tmp/state.json` |
| A6 | `.opencode/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` | 3 | `/tmp/state.json` |
| A7 | `.opencode/extensions/founder/skills/skill-consult/SKILL.md` | 1 | `/tmp/consult-meta-${session_id}.json` |
| A8 | `.opencode/extensions/filetypes/agents/spreadsheet-agent.md` | 1 | `/tmp/temp_data.csv` |

**Notes**:
- A1-A6 all follow the same simple `/tmp/state.json` pattern -- straightforward replacement
- A7 uses a unique temp path (`/tmp/consult-meta-${session_id}.json`) for standalone mode. This needs the same treatment: change to `specs/tmp/consult-meta-${session_id}.json`
- A8 uses `/tmp/temp_data.csv` in a Python example within an agent definition. Change to `specs/tmp/temp_data.csv`

### Category B: Core Context Patterns (2 files, ~9 refs)

These are context documentation files that contain example code with `/tmp/` paths.

| # | File | Refs | Details |
|---|------|------|---------|
| B1 | `.opencode/context/core/patterns/file-metadata-exchange.md` | 4 | Uses `/tmp/meta_base.json`, `/tmp/meta_with_artifacts.json` in Pattern 2 example |
| B2 | `.opencode/context/core/patterns/jq-escaping-workarounds.md` | 5 | Uses `/tmp/test-specs/state.json` for test script examples |

**Notes**:
- B1: The duplicate at `.opencode/context/patterns/file-metadata-exchange.md` already uses `specs/tmp/`. Only the core/ version needs fixing.
- B2: Test script uses `/tmp/test-specs/` directory; should change to `specs/tmp/test-specs/`

### Category C: Project Context Processes (3 files, ~7 refs)

These are the "project" versions of workflow documentation that use `/tmp/` instead of `specs/tmp/` like their core counterparts.

| # | File | Refs | Details |
|---|------|------|---------|
| C1 | `.opencode/context/project/processes/research-workflow.md` | 3 | `/tmp/task-${task_number}.md` |
| C2 | `.opencode/context/project/processes/implementation-workflow.md` | 2 | `/tmp/task-${task_number}.md` |
| C3 | `.opencode/context/project/processes/planning-workflow.md` | 2 | `/tmp/task-${task_number}.md` |

**Notes**:
- All are examples of selective task extraction from specs/TODO.md
- The core counterparts (`.opencode/context/core/processes/`) already use `specs/tmp/task-${task_number}.md`
- These project/ versions are clearly outdated copies that need updating

### Category D: Documentation Guides (1 file, ~6 refs)

| # | File | Refs | Details |
|---|------|------|---------|
| D1 | `.opencode/docs/guides/tts-stt-integration.md` | 6 | Old `/tmp/` paths for TTS cooldown files, logs, recordings |

**Notes**:
- References `/tmp/claude-tts-last-notify`, `/tmp/opencode-tts-notify.log`, `/tmp/test.wav`, `/tmp/nvim-stt-recording.wav`
- These paths have been migrated to `specs/tmp/` already; the documentation is outdated
- Should update to reflect current `specs/tmp/` locations

### Category E: No Change Needed (for reference)

These contain `/tmp/` substring but should NOT be changed:

- **All files using `specs/tmp/`** (~100+/124 files): Already correct, the desired target location
- `.opencode/docs/guides/opencode-permission-configuration.md`: Documents the `/tmp/` to `specs/tmp/` migration history; these are historical/educational references, not active path usage
- `.opencode/docs/guides/permission-configuration.md`: Error message example showing denied `/tmp/old` command; illustrative, not an active path
- `.opencode/templates/opencode.json`: Prompt text mentioning `/tmp/` in agent instructions to discourage its use; fine as-is
- `.opencode/output/implement.md`: Uses `specs/tmp/state.json`; already correct

### Existing `specs/tmp/` Status

The `specs/tmp/` directory exists and contains:
- `claude-tts-last-notify` -- TTS notification cooldown timestamp
- `claude-tts-notify.log` -- TTS notification log

This confirms that hook scripts and postflight scripts already correctly write to `specs/tmp/` and the migration target is viable.

## Decisions

- **Focus scope**: Prioritize active bash command references (Categories A, B, C) over documentation (Category D) since documentation doesn't cause runtime permission prompts
- **Replacement pattern**: All `> /tmp/state.json` patterns should become `> specs/tmp/state.json` -- a direct substitution with no structural change needed
- **spreadsheet-agent exception**: `/tmp/temp_data.csv` in the spreadsheet agent is a Python code block example; changing it to `specs/tmp/temp_data.csv` keeps it within project scope

## Recommendations

1. **Category A (Extension SKILL.md files)**: Perform sed-style replacement of all `/tmp/state.json` with `specs/tmp/state.json` and `/tmp/consult-meta-` with `specs/tmp/consult-meta-` and `/tmp/temp_data.csv` with `specs/tmp/temp_data.csv`. This is high priority.
2. **Category B (Core context patterns)**: Update the core/context/patterns/ files to use `specs/tmp/` instead of `/tmp/` for consistency. Medium priority.
3. **Category C (Project context processes)**: Update the project/processes/ files to use `specs/tmp/` instead of `/tmp/`. These are documentation but reference outdated patterns. Medium priority.
4. **Category D (Documentation guides)**: Update `tts-stt-integration.md` to reflect current `specs/tmp/` paths. Low priority.

## Risks & Mitigations

- **Breaking extension workflows**: If replacement misses a file, that extension's postflight will trigger an external_directory prompt. Mitigation: systematic sed across all extensions.
- **Duplicate paths**: The `specs/tmp/state.json` already gets used by core skills; extension uses won't collide since postflights run sequentially. Mitigation: verify no concurrent writes.
- **spreadsheet-agent**: Changing the Python example path is cosmetic but ensures consistency with the project's temp file policy. Risk: zero.

## Context Extension Recommendations

- **Topic**: Temp file path conventions
- **Gap**: No dedicated context file documenting the `specs/tmp/` convention for agents
- **Recommendation**: The `opencode-permission-configuration.md` guide already documents this well. Consider adding a one-liner to `.opencode/AGENTS.md` or `CLAUDE.md` that all temp files should use `specs/tmp/`, never `/tmp/`.

## Appendix

### Search Queries Used
- `grep -rn '/tmp/' .opencode/ --include='*.md' --include='*.sh' --include='*.json' --include='*.js' | grep -v node_modules | grep -v 'specs/tmp/'`
- `grep -rn '/tmp/opencode' .opencode/ --include='*.md' --include='*.sh'`
- `ls specs/tmp/` to check existing directory state

### Key Reference Files
- `.opencode/extensions/core/skills/skill-implementer/SKILL.md` (correct reference implementation using `specs/tmp/`)
- `.opencode/scripts/postflight-implement.sh` (correct postflight using `specs/tmp/`)
- `.opencode/context/patterns/file-metadata-exchange.md` (correct context version using `specs/tmp/`)
- `.opencode/context/core/processes/research-workflow.md` (correct core version using `specs/tmp/`)
