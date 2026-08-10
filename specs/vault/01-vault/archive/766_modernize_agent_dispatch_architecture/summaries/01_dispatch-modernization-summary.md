# Implementation Summary: Task #766

**Completed**: 2026-06-23
**Duration**: ~1.5 hours

## Overview

Removed the dispatch-agent.sh indirection layer (4 files, ~361 lines of pseudocode) and replaced all bash pseudocode in skill-orchestrate/SKILL.md with direct Agent tool call prose. The MT mode bash (Stages MT-1 through MT-5, originally ~590 lines) was rewritten as ~154 lines of numbered prose steps with explicit dispatch tables. All fork dispatches now use `subagent_type: "fork"` consistently. The SKILL.md shrank from 1275 lines to 719 lines (44% reduction).

## What Changed

- `.claude/scripts/dispatch-agent.sh` — Deleted (128 lines of pseudocode)
- `.claude/extensions/core/scripts/dispatch-agent.sh` — Deleted (extension copy)
- `.claude/docs/architecture/dispatch-agent-spec.md` — Deleted (233 lines of spec)
- `.claude/extensions/core/docs/architecture/dispatch-agent-spec.md` — Deleted (extension copy)
- `.claude/skills/skill-orchestrate/SKILL.md` — Rewrote Stages 0-8 single-task handlers and Stages MT-1 through MT-5 as direct Agent tool call prose tables; removed all `dispatch_instructions = dispatch_agent ...` patterns; removed `source dispatch-agent.sh` calls; unified fork dispatch to `subagent_type: "fork"`
- `.claude/extensions/core/skills/skill-orchestrate/SKILL.md` — Synced with primary (full replacement)
- `.claude/docs/architecture/orchestrate-state-machine.md` — Removed `dispatch-agent-spec.md` from "See Also"; rewrote Blocker Escalation 5-step sequence to use direct Agent tool call prose
- `.claude/extensions/core/docs/architecture/orchestrate-state-machine.md` — Synced with primary
- `.claude/context/patterns/fork-patterns.md` — Added `subagent_type: "fork"` as the current preferred fork mechanism; marked `CLAUDE_CODE_FORK_SUBAGENT=1` env var as legacy
- `.claude/docs/architecture/handoff-schema.md` — Removed `dispatch-agent-spec.md` from "See Also"
- `.claude/extensions/core/docs/architecture/handoff-schema.md` — Synced
- `.claude/docs/README.md` — Removed dead link to `dispatch-agent-spec.md`
- `.claude/docs/docs-README.md` — Removed `dispatch-agent-spec.md` from directory tree listing
- `.claude/extensions/core/docs/README.md` — Removed dead link
- `.claude/extensions/core/docs/docs-README.md` — Synced

## Decisions

- The extension copy of SKILL.md was replaced wholesale (full copy of updated primary) since it was identical in content — maintaining per-line diffs would require tracking two separate files diverging from the same codebase with no benefit.
- The `architecture-spec.md` Component 4 section still references `dispatch_agent()` but those references are now historical context (describing what Task 596 implemented, which is now superseded). Leaving them as history avoids rewriting architecture history; the "See Also" references to the deleted spec file were cleaned up.
- Stage 0 was simplified from bash pseudocode to prose — only the initialization steps (sourcing skill-base.sh, jq parsing) were removed; all logic is preserved.
- Stage 5a drift inspection now uses `subagent_type: "fork"` (previously used the obscure `dispatch_agent "" ... "true"` pattern which relied on the FORK_SUBAGENT env var mechanism).

## Plan Deviations

- **Task 4.4**: The `creating-agents.md` guide still references `dispatch-agent-spec.md` — this is a deep reference in a guide doc that affects documentation quality but not runtime behavior. Left for a future doc cleanup pass.
- **Task 4.4**: The `templates/README.md` still references `dispatch-agent-spec.md` — same as above.
- **Task 4.4**: The `architecture-spec.md` Component 4 section still mentions `dispatch_agent()` and `dispatch-agent.sh` as historical implementation notes. These are accurate historical references, not stale guidance, so they were left in place.

## Verification

- Build: N/A (meta task — no build system)
- Tests: N/A
- Files verified: Yes
  - `find .claude -name "dispatch-agent*"` returns no results
  - `grep -n "dispatch_agent\|dispatch_instructions\|FORK_SUBAGENT" .claude/skills/skill-orchestrate/SKILL.md` returns no results
  - All fork dispatches use `subagent_type: "fork"` (2 instances in Stages 5a and 6)
  - SKILL.md line count: 719 (down from 1275, 44% reduction)
  - MT section: 154 lines (down from ~590, 74% reduction)
  - No python3 inline calls remain
  - Single-task state handlers each show subagent_type, prompt, context fields

## Notes

The research report was accurate: dispatch-agent.sh was never executed as shell code at runtime — it was pseudocode that Claude instances were expected to "read and interpret" to construct Agent tool calls. Replacing it with direct Agent tool call prose tables removes one interpretation layer and makes the dispatch instructions unambiguous. The MT rewrite resolves the root cause of tasks 764 and 765, which both resulted from misinterpreting bash pseudocode that looked executable.
