# Phase 2 Results: Update Command and Skill Guides

**Completed**: 2026-05-22

## Changes Made

### 1. `.claude/docs/guides/creating-commands.md`
- Replaced manual GATE IN/DELEGATE/GATE OUT/COMMIT inline bash snippets in Step 4 with references to shared infrastructure scripts
- Added STAGE 0 section for `parse-command-args.sh` (task number parsing + flag extraction)
- CHECKPOINT 1 now references `command-gate-in.sh` (session gen, task lookup, validation)
- STAGE 2 now references `command-route-skill.sh` (task type -> skill routing)
- CHECKPOINT 2 now references `command-gate-out.sh` (artifact validation, status correction)
- Each script section explains what it exports and handles

### 2. `.claude/docs/templates/command-template.md`
- Complete rewrite to use shared gate scripts instead of manual skill-status-sync and session ID generation
- Template now follows the exact pattern used by refactored commands (research.md, plan.md, implement.md)
- Updated frontmatter model recommendation from `opus` to `sonnet` (dispatch commands)
- Added Options table, multi-task dispatch reference, and proper STAGE 0/CHECKPOINT structure

### 3. `.claude/docs/guides/user-guide.md`
- Added "Automation Commands" section (between Maintenance and Utility) with 3 new commands:
  - `/orchestrate N` - autonomous lifecycle with 10-state machine, resume support
  - `/spawn N [blocker]` - blocker analysis and dependency task creation
  - `/merge` - PR/MR creation via `gh pr create`
- Added all 3 commands to Quick Reference table
- Updated Table of Contents with new section numbering
- Updated Last Updated date from 2026-01-28 to 2026-05-22
- Verified `/tag` already present at line 506 -- not duplicated

### 4. `.claude/docs/guides/creating-skills.md`
- Restructured "Skill Template" section into two clear patterns:
  - Pattern A: Core Skills -- uses skill-base.sh directly, shows full lifecycle stage sequence
  - Pattern B: Extension Skills -- uses `context: fork` + `agent:` for thin delegation
- Added Frontmatter Fields table covering both patterns
- Restructured "Step-by-Step Guide" for extension skill creation:
  - Steps now reference skill-base.sh lifecycle functions for all stages
  - Added explicit postflight boundary section (Step 6)
  - Removed inline jq/bash code in favor of skill_base function calls
- The existing skill-base.sh section (lines 78-218) left untouched (already current)

### 5. `.claude/docs/guides/creating-agents.md`
- Added cross-references to Related Documentation:
  - `dispatch-agent-spec.md` -- dispatch_agent() fork-vs-subagent dispatch
  - `handoff-schema.md` -- Orchestrator handoff JSON schema

## Verification

- creating-commands.md: 8 references to shared gate scripts (was 0)
- command-template.md: 4 references to shared gate scripts (was 0)
- user-guide.md: /orchestrate, /spawn, /merge in TOC, sections, and quick reference
- creating-skills.md: 33 references to skill-base.sh lifecycle functions
- creating-agents.md: dispatch-agent-spec.md and handoff-schema.md linked
