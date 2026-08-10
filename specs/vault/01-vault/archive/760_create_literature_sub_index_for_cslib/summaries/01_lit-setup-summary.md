# Implementation Summary: Task #760

**Completed**: 2026-06-23
**Duration**: ~1 hour

## Overview

Added interactive detection to the `--lit` flag processing path in all 6 skill SKILL.md files.
When `--lit` is used and `specs/literature-index.json` does not exist, the skill now presents
an `AskUserQuestion` prompt offering three choices: skip, create a setup task, or create a setup
task and populate the sub-index inline via a fork agent. A shared bash helper script was created
to handle the programmatic task creation side effect.

## What Changed

- `.claude/scripts/literature-create-setup-task.sh` — Created new shared helper that programmatically
  inserts a `populate_literature_sub_index` task into `specs/state.json` and syncs `TODO.md`.
  Outputs the new task number to stdout for the calling skill to capture.

- `.claude/skills/skill-researcher/SKILL.md` — Added `AskUserQuestion` to `allowed-tools`;
  replaced the existing single-call `literature-briefing.sh` invocation in Stage 4a with a
  detection block that checks for a missing sub-index and presents interactive setup options,
  followed by a conditional `literature-briefing.sh` call that only runs when the sub-index exists.

- `.claude/skills/skill-planner/SKILL.md` — Same Stage 4a changes as skill-researcher.

- `.claude/skills/skill-implementer/SKILL.md` — Same Stage 4a changes as skill-researcher.

- `.claude/skills/skill-researcher-hard/SKILL.md` — Same Stage 4a changes as skill-researcher.

- `.claude/skills/skill-planner-hard/SKILL.md` — Same Stage 4a changes as skill-researcher.

- `.claude/skills/skill-implementer-hard/SKILL.md` — Same Stage 4a changes as skill-researcher.

- `.claude/scripts/literature-briefing.sh` — Updated header comment to document that interactive
  detection is now handled upstream in skills; the script's silent-exit behavior is unchanged.

- `.claude/extensions/core/merge-sources/claudemd.md` — Added "Interactive Sub-Index Setup
  Detection" subsection to the Literature Mode documentation.

- `.claude/CLAUDE.md` — Mirrored the same "Interactive Sub-Index Setup Detection" subsection
  into the generated CLAUDE.md file.

## Decisions

- Detection block is implemented inline in each SKILL.md as pseudocode (not executable bash)
  because `AskUserQuestion` is a Claude tool that must be invoked directly by Claude during
  skill execution, not from a sourced shell script.
- All bash side-effect logic (state.json update, TODO.md sync) is extracted into the shared
  `literature-create-setup-task.sh` script to avoid code duplication across 6 skills.
- The existing `literature-briefing.sh` call is replaced with a conditional call gated on
  `specs/literature-index.json` existing, so the script is only called when the sub-index
  is present (matches the script's own bail-early behavior for the same condition).
- The Stage 4a-fork section describes the fork dispatch pattern as prose instructions for
  Claude to follow when the user selects "Create task and run now". This is appropriate because
  the Agent tool call itself cannot be pre-scripted in a bash code block.

## Plan Deviations

- None (implementation followed plan exactly; Phases 2 and 3 were combined naturally since the
  fork-orchestrate logic was incorporated directly into the detection block prose during Phase 2)

## Verification

- Build: N/A (skill SKILL.md files are documentation/instructions, not compiled code)
- Tests: N/A
- Files verified: All 6 SKILL.md files confirmed to have `AskUserQuestion` in frontmatter
  and the detection block in Stage 4a via grep verification
- Script syntax check: `bash -n literature-create-setup-task.sh` passed

## Notes

- The detection block in all 6 SKILL.md files is identical (copy-paste consistent), satisfying
  the consistency requirement from the plan.
- `AskUserQuestion` has been added to the `allowed-tools` frontmatter of all 6 skills to
  grant Claude permission to invoke it during skill execution.
- The global Literature index path respects the `$LITERATURE_DIR` environment variable, with
  `~/Projects/Literature` as the default fallback.
