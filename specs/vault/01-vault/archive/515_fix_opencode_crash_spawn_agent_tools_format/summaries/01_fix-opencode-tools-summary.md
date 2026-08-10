# Implementation Summary: Task #515

- **Task**: 515 - Fix opencode startup crash caused by spawn-agent.md tools format mismatch
- **Status**: [COMPLETED]
- **Started**: 2026-05-02T00:00:00Z
- **Completed**: 2026-05-02T00:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Artifacts**:
  - [specs/515_fix_opencode_crash_spawn_agent_tools_format/reports/01_opencode-crash-tools-format.md]
  - [specs/515_fix_opencode_crash_spawn_agent_tools_format/plans/01_fix-opencode-tools-format.md]
  - [specs/515_fix_opencode_crash_spawn_agent_tools_format/summaries/01_fix-opencode-tools-summary.md]
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary.md

## Overview

Updated the opencode frontmatter documentation to accurately reflect runtime behavior for the `tools` field, which was the root cause of an opencode startup crash (already fixed in commit 7afea460d). The documentation now correctly marks `tools` as optional and warns against using YAML array format, which crashes the opencode runtime. Added a cross-system porting guide to prevent similar issues when copying agent definitions between Claude Code and opencode.

## What Changed

- Updated `.opencode/context/formats/frontmatter.md` Section 9: changed `tools` from Required to Optional with runtime behavior documentation
- Added warning that YAML array format for `tools` crashes opencode on startup
- Added "Cross-System Porting Warning" section with comparison table and checklists for both directions
- Updated example agents to show `tools` field omitted (recommended practice)
- Updated Best Practices section to recommend omitting tools field entirely

## Decisions

- Marked `tools` as Optional rather than removing it from the schema, since object-format override may be valid
- Added explicit crash warning in the field documentation rather than just a note, given the severity of the issue
- Included both Claude Code-to-opencode and opencode-to-Claude Code porting checklists for completeness

## Impacts

- Prevents future opencode crashes from tools field format mismatch when porting agents
- Frontmatter documentation now matches actual runtime behavior
- No breaking changes to existing subagent files (they already omit the tools field)

## Follow-ups

- Consider building automated frontmatter validation that catches YAML array tools fields
- The opencode.lua provider-to-server migration was already committed during planning phase

## References

- `.opencode/context/formats/frontmatter.md` - Updated documentation
- `specs/515_fix_opencode_crash_spawn_agent_tools_format/plans/01_fix-opencode-tools-format.md` - Implementation plan
- Crash fix commit: 7afea460d (tools field removed from spawn-agent.md)
