# Implementation Summary: Fix OpenCode Model Not Found Error

- **Task**: 529 - Fix 'Model not found: opus/' error in .opencode/ agent system
- **Status**: [COMPLETED]
- **Started**: 2026-05-04T00:00:00Z
- **Completed**: 2026-05-04T00:15:00Z
- **Effort**: 15 minutes
- **Dependencies**: None
- **Artifacts**: [specs/529_fix_opencode_model_not_found_opus_error/plans/01_fix-model-references.md]
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Removed invalid `model:` frontmatter from 34 files in the `.opencode/` agent system that were causing "Model not found: opus/" errors. OpenCode's `parseModel()` splits model strings by `/`, so bare aliases like `"opus"` produced `{providerID: "opus", modelID: ""}` which failed model resolution. The fix removes the field entirely so users' session model selection takes precedence.

## What Changed

- Removed `model: opus` from 17 command files in `.opencode/commands/`
- Removed `model: opus` from 15 command files in `.opencode/extensions/core/commands/`
- Removed `model: sonnet` from `.opencode/agent/orchestrator.md`
- Removed `model: opus` from `.opencode/context/templates/command-template.md`
- Updated `.opencode/docs/guides/creating-commands.md` to note that `model:` is not supported in OpenCode
- Updated `.opencode/docs/reference/standards/agent-frontmatter-standard.md` (and extension copy) to document that `model:` is Claude Code-only
- Updated `.opencode/context/templates/agent-template.md` to remove model references from agent type variants

## Decisions

- Removed `model:` entirely rather than converting to `provider/model` format (per research recommendation)
- Updated documentation to explicitly warn against using `model:` in OpenCode frontmatter
- Left `.claude/` system untouched (it correctly supports the `model:` field)
- Left command body references to `model_flag` delegation context (these describe runtime flag passing, not frontmatter)

## Impacts

- All `.opencode/` commands will now use the session model selected by the user in the TUI model picker
- No more "Model not found: opus/" errors when executing OpenCode commands
- Documentation now accurately distinguishes Claude Code vs OpenCode frontmatter capabilities
- Other projects that sync from this `.opencode/` will get the fix on next sync

## Follow-ups

- None required

## References

- `specs/529_fix_opencode_model_not_found_opus_error/reports/01_model-not-found-research.md`
- `specs/529_fix_opencode_model_not_found_opus_error/plans/01_fix-model-references.md`
