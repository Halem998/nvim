# Research Report: Task #184

**Task**: 184 - revise_learn_command_input_modes
**Started**: 2026-03-11T00:00:00Z
**Completed**: 2026-03-11T00:05:00Z
**Effort**: 1-2 hours estimated for implementation
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of .opencode/extensions/memory/
**Artifacts**: specs/184_revise_learn_command_input_modes/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- The current /learn command in `.opencode/extensions/memory/` already supports two of the four requested modes: text input and single file path
- The --task N mode is already fully implemented with artifact scanning and classification
- **Missing modes**: directory path scanning and explicit prompt text (currently text is treated as fallback when path doesn't exist)
- Implementation requires changes to two files: `commands/learn.md` (argument parsing) and `skills/skill-memory/SKILL.md` (execution logic)
- The /fix command provides a good pattern for directory scanning that can be adapted

## Context and Scope

The task asks to revise the /learn command to accept four distinct input modes:
1. **File path** - Extract content from a single file
2. **Directory path** - Extract content from all files in a directory
3. **Prompt text** - Extract memories from provided text
4. **--task N flag** - Extract memories from task artifacts

## Findings

### Current Implementation Analysis

The /learn command lives at `.opencode/extensions/memory/commands/learn.md` and delegates to `skill-memory` defined at `.opencode/extensions/memory/skills/skill-memory/SKILL.md`.

**Current argument parsing** (from learn.md lines 15-32):

```
1. Check for --task flag -> Task mode
2. Otherwise: first argument is text/file
   - If path exists on disk: treat as file
   - If path doesn't exist: treat as text content
```

This is a simple two-branch parser. The file-vs-text distinction uses filesystem existence as a heuristic, which is fragile (a typo in a path silently becomes text input).

**Current modes**:

| Mode | Status | How it works |
|------|--------|-------------|
| Text input | Implemented | Fallback when path doesn't exist on disk |
| Single file | Implemented | Detected by `file_exists(input)` |
| Directory | NOT implemented | No directory detection or recursive scanning |
| --task N | Implemented | Full artifact scanning with classification taxonomy |

### Skill-Memory Execution

The skill (`SKILL.md`) implements two execution paths:

1. **Standard mode** (`mode=standard`): Parses input as file or text, generates memory ID, searches for similar memories, presents preview with AskUserQuestion, creates memory file in `.memory/10-Memories/`, updates index.
2. **Task mode** (`mode=task`): Locates task directory, scans for `.md` artifacts, presents interactive selection, classifies each artifact with 6-category taxonomy, creates tagged memories.

### Patterns from Other Commands

**`/fix` command** (`commands/fix.md`): Accepts optional path arguments. If no paths: scans entire project. If paths provided: scans specified files/directories. This is the closest pattern for directory support.

**`/task` command** (`commands/task.md`): Uses flag-based mode selection: no flags = create, `--recover N`, `--expand N "prompt"`, `--sync`, `--abandon N`. This is the pattern for multi-mode flag parsing.

**`/research` command** (`commands/research.md`): Combines positional args (task number) with optional flags (`--remember`) and trailing text (focus prompt). Demonstrates mixed positional + flag parsing.

### Implementation Approach for Four Input Modes

#### Mode Detection Logic (Revised)

The argument parser needs a clear priority chain:

```
1. --task N present?          -> Task mode (existing)
2. First arg is directory?    -> Directory mode (NEW)
3. First arg is file?         -> File mode (existing, refine)
4. Otherwise                  -> Prompt text mode (existing, refine)
```

#### Mode 1: File Path (Existing - Refine)

Current implementation works but should be made more explicit:
- Use `-f "$input"` test
- Source metadata should record the file path
- Content extraction reads the entire file

No major changes needed. Only needs clearer separation from text mode.

#### Mode 2: Directory Path (NEW)

This is the primary new capability. Recommended approach:

**Argument detection**: Use `-d "$input"` test after --task check.

**Scanning logic** (adapted from /fix pattern):
```bash
# Find all readable files in directory
files=$(find "$input" -type f -name "*.md" -o -name "*.lua" -o -name "*.txt" -o -name "*.json" | sort)
```

**Interactive selection**: Present file list via AskUserQuestion with multiSelect (same pattern as task mode artifact selection).

**Per-file processing**: For each selected file, run standard mode processing:
- Generate memory preview
- Search for similar memories
- Present add/update/edit/skip options
- Create memory with `source: "directory: {dir_path}/{filename}"`

**Batch mode consideration**: For directories with many files, consider a batch summary rather than per-file interactive flow. Present all files, let user select which to include, then process selected files with a single classification pass.

#### Mode 3: Prompt Text (Existing - Refine)

Current implementation treats non-file input as text. This works but could be improved:
- Accept quoted strings explicitly
- Support multi-word text without requiring quotes (join remaining args)
- Consider supporting stdin piping in future

No major changes needed beyond clearer documentation and argument joining.

#### Mode 4: --task N (Existing - Complete)

Fully implemented with:
- Task directory location (padded/unpadded number handling)
- Artifact scanning across reports/, plans/, summaries/, code/
- Interactive multi-select for artifact review
- 6-category classification taxonomy
- Memory creation with task reference tags
- Index updates

No changes needed.

### Files Requiring Modification

| File | Changes |
|------|---------|
| `.opencode/extensions/memory/commands/learn.md` | Add directory detection to argument parsing, add directory mode to workflow |
| `.opencode/extensions/memory/skills/skill-memory/SKILL.md` | Add `mode=directory` execution path with scanning, selection, and batch processing |
| `.opencode/extensions/memory/EXTENSION.md` | Update command usage table to include directory mode |
| `.opencode/extensions/memory/context/project/memory/learn-usage.md` | Add directory mode usage examples |

### Argument Parsing Design

Recommended revised argument parsing for learn.md:

```
<argument_parsing>
  <step_1>
    Parse arguments:
    - Check for --task flag: `--task N`
    - If --task present: Task mode

    If not task_mode:
      input = remaining args joined with spaces

      - If input is a directory (-d test): Directory mode
      - If input is a file (-f test): File mode
      - Otherwise: Prompt text mode

    mode = "task" | "directory" | "file" | "text"
  </step_1>
</argument_parsing>
```

Skill delegation becomes:
```
skill: "skill-memory"
args: "mode={mode}, input={input}, task_number={task_number}"
```

### Directory Mode Skill Execution Design

New section in SKILL.md:

1. **Scan directory**: Find files matching common patterns (*.md, *.lua, *.txt, *.json, *.py, etc.)
2. **Present file list**: AskUserQuestion with multiSelect showing file names and sizes
3. **Process selected files**: For each file:
   - Read content
   - Generate memory preview (truncated)
   - Search for similar memories
4. **Batch classification**: Present all selected files with classification options (reuse task mode taxonomy or standard add/update/skip)
5. **Create memories**: Generate memory files for each non-skipped file
6. **Update index**: Add all new memories to index.md

### Usage Examples (Post-Implementation)

```bash
/learn "Use pcall() in Lua for safe function calls"    # Prompt text mode
/learn /path/to/notes.md                                # File mode
/learn /path/to/research-notes/                          # Directory mode
/learn --task 142                                        # Task mode
```

## Decisions

- Directory mode should reuse the interactive selection pattern from task mode (AskUserQuestion with multiSelect)
- File type filtering should be configurable but default to common text formats (*.md, *.lua, *.txt, *.json, *.py, *.sh)
- Batch processing is preferred over per-file interactive for directories (fewer user interactions)
- The existing file-vs-text heuristic (filesystem existence test) is acceptable and should be preserved
- No new flags needed beyond --task; mode is determined by input type

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Large directories overwhelming the user | Limit file listing to 50 files, show count and suggest narrowing path |
| Binary files being scanned | Filter by extension (whitelist text formats) |
| Path ambiguity (file named same as directory) | -d test takes priority over -f test; directories are checked first |
| Empty directories | Graceful error: "No supported files found in {path}" |

## Appendix

### Files Examined

- `.opencode/extensions/memory/commands/learn.md` - Current command definition
- `.opencode/extensions/memory/skills/skill-memory/SKILL.md` - Current skill implementation
- `.opencode/extensions/memory/EXTENSION.md` - Extension manifest
- `.opencode/extensions/memory/context/project/memory/learn-usage.md` - Usage guide
- `.opencode/extensions/memory/context/project/memory/knowledge-capture-usage.md` - Cross-feature examples
- `.opencode/extensions/memory/data/.memory/30-Templates/memory-template.md` - Memory template
- `.opencode/commands/fix.md` - Pattern for directory/file path handling
- `.opencode/commands/task.md` - Pattern for flag-based mode parsing
- `.opencode/commands/research.md` - Pattern for mixed positional + flag parsing
