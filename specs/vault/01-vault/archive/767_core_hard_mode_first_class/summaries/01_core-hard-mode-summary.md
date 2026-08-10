# Implementation Summary: Task #767

**Completed**: 2026-06-24
**Duration**: ~0.5 hours

## Overview

Promoted hard-mode capability to a first-class part of the core extension source tree. Copied 3 hard agent files into `.claude/extensions/core/agents/`, authored `skill-orchestrate-hard/SKILL.md` into `.claude/extensions/core/skills/`, and updated `core/manifest.json` to declare 3 new agents, 4 new skills, and a `routing_hard` section covering general/meta/markdown x research/plan/implement.

## What Changed

- `.claude/extensions/core/agents/general-research-hard-agent.md` - New verbatim copy from deployed
- `.claude/extensions/core/agents/planner-hard-agent.md` - New verbatim copy from deployed
- `.claude/extensions/core/agents/general-implementation-hard-agent.md` - New copy with portability path fix (3 occurrences)
- `.claude/agents/general-implementation-hard-agent.md` - Path fix applied (lockstep with core source)
- `.claude/extensions/core/skills/skill-orchestrate-hard/SKILL.md` - New verbatim copy from deployed
- `.claude/extensions/core/manifest.json` - Added 3 hard agents to provides.agents, 4 hard skills to provides.skills, new routing_hard section

## Decisions

- Applied relative-path fix (`bash .claude/scripts/...` replacing `bash /home/benjamin/.config/nvim/.claude/scripts/...`) to both core source and deployed files simultaneously to maintain lockstep.
- Added `routing_hard` as a new top-level key in manifest.json, mirroring cslib's schema shape.
- All 3 hard skills that were already in core/skills/ (skill-researcher-hard, skill-planner-hard, skill-implementer-hard) only needed manifest listing, not file creation; skill-orchestrate-hard required both directory/file creation and manifest listing.

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: N/A
- Files verified: Yes
  - All 3 hard agent files exist in core/agents/ with correct frontmatter names
  - Zero absolute-path references remain in either copy of general-implementation-hard-agent.md
  - Exactly 3 relative path references present in core source copy
  - Core and deployed copies of general-research-hard-agent.md and planner-hard-agent.md are byte-identical
  - skill-orchestrate-hard/SKILL.md exists and is identical to deployed
  - manifest.json passes jq empty (valid JSON)
  - provides.agents length = 11, provides.skills length = 23
  - All routing_hard skill references appear in provides.skills
  - All provides.agents entries have backing files in core/agents/
  - All provides.skills entries have backing directories in core/skills/
  - check-extension-docs.sh: 2 pre-existing FAILs (dispatch-agent.sh missing on disk, /zulip not in README) — both attributable to tasks predating 767 (dispatch-agent.sh at manifest index 9 since before task 767, /zulip gap from task 740)

## Notes

The doc-lint non-zero exit (exit code 1) is exclusively caused by two pre-existing issues:
1. `dispatch-agent.sh` listed in manifest scripts but missing on disk — present at index 9 in the committed manifest before this task.
2. `/zulip` command listed in manifest but not mentioned in README.md — gap created by task 740.

Neither issue was introduced by task 767. Tasks 768, 769, and 770 can proceed; they depend on the declarations added here.
