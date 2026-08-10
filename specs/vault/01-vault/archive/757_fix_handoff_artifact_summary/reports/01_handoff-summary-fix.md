# Research Report: Add summary field to skill_write_orchestrator_handoff artifacts

**Task**: 757
**Status**: Researched
**Date**: 2026-06-22

## Problem

In `.claude/scripts/skill-base.sh` line 436, `skill_write_orchestrator_handoff()` builds the artifacts JSON without a `summary` field:

```bash
artifacts_json=$(printf '[{"type":"%s","path":"%s"}]' "$artifact_type" "$artifact_path")
```

When orchestrate's Stage 5 reads this handoff and calls `skill_link_artifacts`, the summary is empty, which overwrites any artifact data that the standalone skill's Stage 8 may have already linked with a proper summary.

## Root Cause

The function signature takes 9 parameters (`$1`-`$9`), with `$7` = artifact_path and `$8` = artifact_type. There is no parameter for artifact_summary. The `printf` on line 436 only includes `type` and `path`.

## Fix

1. **Add 10th parameter** `artifact_summary` to the function (use `${10}` syntax since bash positional params beyond `$9` require braces)
2. **Replace `printf` with `jq`** on line 436 to properly escape the summary string (summaries may contain quotes/special chars)
3. **Update usage comment** at lines 384-386 to document the new parameter
4. **Update callers**: The function is defined in skill-base.sh and called by skill postflight stages. Callers must pass the artifact summary from `.return-meta.json`.

## Callers

Currently `skill_write_orchestrator_handoff` is not called directly from any skill SKILL.md files or other scripts — it's a helper function available when `skill-base.sh` is sourced. The function is invoked by skill postflight code that follows the SKILL.md instructions. Adding the parameter is backward-compatible since existing callers can omit it (summary defaults to empty).

## Files to Modify

1. `.claude/scripts/skill-base.sh` — function definition (lines 384-475)
