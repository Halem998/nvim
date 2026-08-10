# Implementation Plan: Task #184

- **Task**: 184 - revise_learn_command_input_modes
- **Status**: [NOT STARTED]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: specs/184_revise_learn_command_input_modes/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false
- **Date**: 2026-03-11
- **Feature**: Add directory scanning mode to /learn command for batch memory extraction
- **Estimated Hours**: 1-2 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)

## Overview

The /learn command currently supports three modes: text input, single file path, and --task N. This plan adds a fourth mode -- directory path scanning -- which allows users to point /learn at a directory and interactively select files for batch memory extraction. The implementation touches four files across the memory extension, with the primary new logic in the command argument parser and the skill execution path.

### Research Integration

Research confirmed that two modes (text, file) already work via filesystem existence heuristic, and --task mode is fully implemented. The /fix command provides a reusable pattern for directory scanning. The key design decision is to check `-d` before `-f` in the argument parser, and to reuse the task mode's AskUserQuestion multiSelect pattern for file selection.

## Goals and Non-Goals

**Goals**:
- Add directory path detection to /learn argument parsing
- Implement `mode=directory` execution path in skill-memory
- Support interactive file selection from scanned directories
- Batch-process selected files into individual memories
- Update documentation and usage examples

**Non-Goals**:
- Recursive subdirectory scanning (keep to single directory level initially)
- Binary file content extraction
- Automatic classification for directory mode (use standard add/update/skip flow)
- Stdin piping support

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Large directories overwhelm user | M | M | Cap file listing at 50 files, show total count |
| Binary files in scan results | L | M | Whitelist text extensions only |
| Path ambiguity (file vs directory) | L | L | Check `-d` before `-f` in priority chain |
| Empty directory with no matching files | L | M | Graceful error message with supported extensions list |

## Implementation Phases

### Phase 1: Update Command Argument Parser [NOT STARTED]

**Goal**: Extend learn.md argument parsing to detect directory paths and route to a new `mode=directory` execution path.

**Tasks**:
- [ ] Add directory detection (`-d` test) between --task check and file check in argument parsing
- [ ] Add `mode=directory` to the skill delegation args
- [ ] Update workflow execution to handle directory mode result format
- [ ] Add directory mode to the results presentation step
- [ ] Update error handling section with directory-specific errors

**Timing**: 30 minutes

**Files to modify**:
- `.opencode/extensions/memory/commands/learn.md` - Revise argument_parsing block to add directory detection at priority 2; update workflow_execution to include directory mode delegation and result display; add directory errors to error_handling block

**Verification**:
- Argument parsing section shows 4-mode priority chain: --task, directory, file, text
- Skill delegation includes `mode=directory` path
- Error handling covers "No supported files found in directory" case

---

### Phase 2: Implement Directory Mode in Skill [NOT STARTED]

**Goal**: Add `mode=directory` execution path to SKILL.md with scanning, interactive selection, and batch memory creation.

**Tasks**:
- [ ] Add "Directory Mode: `mode=directory`" to Execution Modes section
- [ ] Create "Directory Mode Execution" section with 7 steps:
  - Step 1: Scan directory for text files (whitelist: *.md, *.lua, *.txt, *.json, *.py, *.sh, *.nix, *.toml, *.yaml, *.yml)
  - Step 2: Validate scan results (cap at 50 files, error on empty)
  - Step 3: Present file list via AskUserQuestion multiSelect
  - Step 4: Process each selected file (read content, generate preview, search similar)
  - Step 5: Present batch preview with per-file add/update/skip options
  - Step 6: Create memory files for non-skipped selections
  - Step 7: Update index and return result
- [ ] Add directory-specific error handling (empty directory, no text files)

**Timing**: 45 minutes

**Files to modify**:
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Add Directory Mode execution section between Standard Mode and Task Mode sections; add directory error handling

**Verification**:
- SKILL.md contains complete Directory Mode Execution section
- Scanning uses extension whitelist (not blacklist)
- File count cap of 50 is enforced before presenting selection
- AskUserQuestion multiSelect pattern matches task mode pattern
- Per-file processing reuses standard mode steps (ID generation, similar search, preview)

---

### Phase 3: Update Documentation [NOT STARTED]

**Goal**: Update EXTENSION.md usage table and learn-usage.md with directory mode examples.

**Tasks**:
- [ ] Add directory mode row to EXTENSION.md command table
- [ ] Add "Adding Directory Memories" section to learn-usage.md
- [ ] Add directory mode example (Example 5) to learn-usage.md
- [ ] Update Quick Reference table in learn-usage.md
- [ ] Update "See Also" or related sections if needed

**Timing**: 15 minutes

**Files to modify**:
- `.opencode/extensions/memory/EXTENSION.md` - Add `/learn /path/to/dir/` row to Commands table
- `.opencode/extensions/memory/context/project/memory/learn-usage.md` - Add directory usage section, example, and update quick reference

**Verification**:
- EXTENSION.md shows all four /learn modes in the command table
- learn-usage.md includes directory mode with example showing interactive selection flow
- Quick reference table lists all four input patterns

---

## Testing and Validation

- [ ] Verify argument parsing correctly identifies directories vs files vs text
- [ ] Verify directory scanning finds only whitelisted file types
- [ ] Verify file count cap prevents overwhelming selection lists
- [ ] Verify empty directory produces graceful error message
- [ ] Verify selected files are processed into individual memories
- [ ] Verify index.md is updated with all new directory-sourced memories
- [ ] Verify documentation is consistent across all four files

## Artifacts and Outputs

- Modified: `.opencode/extensions/memory/commands/learn.md`
- Modified: `.opencode/extensions/memory/skills/skill-memory/SKILL.md`
- Modified: `.opencode/extensions/memory/EXTENSION.md`
- Modified: `.opencode/extensions/memory/context/project/memory/learn-usage.md`

## Rollback/Contingency

All changes are to markdown specification files (no executable code). Rollback is straightforward via `git checkout` of the four modified files. No runtime state or data is affected.
