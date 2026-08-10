# Task 537: Fix Manifest Discovery to Use Absolute Paths

## Problem

Commands that discover extension manifests use relative globs like `.opencode/extensions/*/manifest.json`. In the Task 107 trace, this glob returned no files even though the ProofChecker project had manifests installed. The agent was running with a working directory of `/home/benjamin/.config/nvim` instead of `/home/benjamin/Projects/ProofChecker`.

This is a recurring issue: the agent's shell context is not always anchored to the project root where the command was invoked.

## Impact

- Manifest discovery silently fails when CWD != project root
- Routing falls back to hardcoded tables, losing extension-specific routing
- Agents waste time reasoning about why manifests are missing

## Solution

1. Update all commands (`/implement`, `/research`, `/plan`) to derive **absolute paths** for manifest discovery
2. The project root should be determined from the task's context (e.g., the directory where `specs/state.json` lives, or from the task metadata)
3. Add a working-directory verification step: before globbing, confirm the project root directory exists
4. If manifest discovery fails, produce an explicit error rather than silently falling back

Example:
```bash
project_root="/path/to/project"
for manifest in "$project_root/.opencode/extensions/*/manifest.json"; do
  ...
done
```

## Acceptance Criteria

- [ ] All commands use absolute paths for manifest discovery
- [ ] Working directory is verified before globbing
- [ ] If no manifests are found, an explicit warning/error is emitted
- [ ] Task 107-style trace shows manifests being discovered correctly

## Effort

< 1 hour

## Type

meta

## Dependencies

None

## Key Files

- `.opencode/commands/implement.md`
- `.opencode/commands/research.md`
- `.opencode/commands/plan.md`
