# Research Report: Task #718

**Task**: 718 - Create cite.md command file
**Started**: 2026-06-15T00:00:00Z
**Completed**: 2026-06-15T00:05:00Z
**Effort**: ~30 minutes
**Dependencies**: None
**Sources/Inputs**: literature.md (reference pattern), implement.md (comparison), skill-cite/SKILL.md (first 60 lines)
**Artifacts**: specs/718_create_cite_command_file/reports/01_cite-command-research.md
**Standards**: report-format.md

## Executive Summary

- The command file pattern is straightforward: YAML frontmatter, argument parsing section, workflow execution section, error handling section
- literature.md is the primary reference; it shows multi-mode dispatch using flag-first parsing with a `sub_mode` variable
- skill-cite expects: task number (integer), optional `--gaps` flag, and optional description text after stripping flags/number
- The /cite command needs four modes: task-only, freeform-text-only, task+gaps, and task+focus-text

## Context & Scope

Researched the command file format used in this extension system to create `cite.md` for the `/cite` command. The target file is `.claude/extensions/literature/commands/cite.md`. Key reference was `literature.md` in the same directory.

## Findings

### Command File Format

**Frontmatter** (YAML, 3 fields used in literature.md):
```yaml
---
description: <one-line description shown in /help>
allowed-tools: Skill
argument-hint: "[mode1|mode2|...] [ARGS]"
---
```

The `allowed-tools` field is `Skill` for commands that only delegate to a skill. The `argument-hint` uses bracket/pipe notation for modes and ALLCAPS for variable arguments.

**File Structure** (from literature.md):
1. `# Command: /name` header with purpose, layer, delegate-to
2. `**Input**: $ARGUMENTS`
3. `## Argument Parsing` section with `<argument_parsing>` XML block
4. `## Workflow Execution` section with `<workflow_execution>` XML block
5. `## Error Handling` section
6. Optional: `## State Management` section

### Argument Parsing Pattern

From literature.md, the pattern uses a `sub_mode` default then flag-first matching:

```
sub_mode = "default"

if "--flag1" in $ARGUMENTS:
  sub_mode = "mode1"
  # extract additional args
elif "--flag2" in $ARGUMENTS:
  sub_mode = "mode2"
elif <numeric token> in $ARGUMENTS:
  sub_mode = "task"
  task_num = <extract number>
```

For the /cite command, the modes differ slightly — they are distinguished by whether arguments are numeric vs. quoted text vs. flags. The parsing needs to:
1. Check for `--gaps` flag (additive modifier, not a mode-switch)
2. Check if first non-flag arg is numeric (task mode) or text (freeform mode)
3. Collect remaining text after number/flags as optional focus text

### Skill Delegation Pattern

From implement.md STAGE 2 and literature.md step_2, delegation uses the Skill tool:
```
Invoke Skill tool with:
  skill: "skill-cite"
  args: "mode={sub_mode} task_num={N} show_gaps={true|false} description={text}"
```

The command passes structured args as a flat string. skill-cite parses these from `$ARGUMENTS`.

However, looking at skill-cite/SKILL.md Step 1, it parses from raw `$ARGUMENTS` — it extracts:
- `task_num`: first numeric token
- `show_gaps`: presence of `--gaps`
- `description_override`: remaining text after stripping flags and task_num

This means the command can pass the raw arguments directly to the skill, or restructure them. The literature.md pattern passes `mode={sub_mode} file={file}` style, but for skill-cite we can pass through the cleaned arguments since the skill already has its own parser.

**Recommended delegation**: Pass structured args so skill-cite doesn't need to re-parse:
```
skill: "skill-cite"
args: "task_num={N} show_gaps={true|false} description={text}"
```

Or for freeform mode (no task number):
```
skill: "skill-cite"
args: "description={text} show_gaps={true|false}"
```

### Argument Modes for /cite

From the task description:
| Invocation | Mode | Notes |
|---|---|---|
| `/cite N` | task | Verify citations for task N |
| `/cite "description text"` | freeform | Verify arbitrary text citations |
| `/cite N --gaps` | task+gaps | Task N, show gap items too |
| `/cite N "focus"` | task+focus | Task N with focus text |

Parsing order:
1. Strip `--gaps` flag, set `show_gaps=true`
2. Find first numeric token -> `task_num`
3. Remaining non-flag text -> `description` (focus text or freeform text)
4. If no task_num and no description -> error

### Validation Requirements

From literature.md error handling pattern:
- `/cite` with no args -> usage error
- `/cite N` where N not in state.json -> "Error: Task N not found"
- `/cite "text"` (freeform) -> pass description directly, no task lookup needed

Task validation uses jq against specs/state.json:
```bash
task_data=$(jq -r --argjson num "$task_num" '.active_projects[] | select(.project_number == $num)' specs/state.json 2>/dev/null)
if [ -z "$task_data" ]; then
  error: "Error: Task $task_num not found in specs/state.json"
fi
```

### Frontmatter for cite.md

```yaml
---
description: Verify citations in task artifacts against Literature/ index and Zotero library
allowed-tools: Skill
argument-hint: N [--gaps] ["focus text"] | "description text"
---
```

## Decisions

- Use `Skill` as sole allowed-tool (same as literature.md) — the command only delegates
- Pass structured args to skill-cite rather than raw `$ARGUMENTS`, to make the handoff explicit
- Treat `--gaps` as an additive flag (not a mode switch) that works with both task and freeform modes
- Task validation happens in the command (before delegation), same as literature.md --task mode
- Freeform text mode (no task number) requires description to be non-empty; error if blank

## Risks & Mitigations

- **skill-cite parses its own args**: If we restructure args, skill-cite's Step 1 parser may not match. Mitigation: pass args in the format skill-cite already expects (raw, with task_num as first numeric token), or verify skill-cite can accept structured `key=value` format.
- **Quoted text in freeform mode**: Shell quoting may interfere with `$ARGUMENTS`. Mitigation: document that users should pass text in quotes; the command strips leading/trailing quotes before passing.

## Context Extension Recommendations

None — the command file pattern is already documented in existing context files.

## Appendix

### Files Read
- `/home/benjamin/.config/nvim/.claude/extensions/literature/commands/literature.md` (full)
- `/home/benjamin/.config/nvim/.claude/commands/implement.md` (full)
- `/home/benjamin/.config/nvim/.claude/extensions/literature/skills/skill-cite/SKILL.md` (lines 1-60)
