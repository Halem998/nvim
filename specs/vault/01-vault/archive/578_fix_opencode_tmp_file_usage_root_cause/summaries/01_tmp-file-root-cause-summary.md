# Implementation Summary: Task #578 - fix_opencode_tmp_file_usage_root_cause

- **Task**: 578 - fix_opencode_tmp_file_usage_root_cause
- **Status**: [COMPLETED]
- **Started**: 2026-05-14T00:00:00Z
- **Completed**: 2026-05-14T01:00:00Z
- **Effort**: ~1 hour
- **Dependencies**: Task 574 (prior fix for mktemp calls -- already completed)
- **Artifacts**:
  - `specs/578_fix_opencode_tmp_file_usage_root_cause/reports/01_tmp-file-root-cause.md`
  - `specs/578_fix_opencode_tmp_file_usage_root_cause/plans/01_tmp-file-root-cause.md`
  - `specs/578_fix_opencode_tmp_file_usage_root_cause/summaries/01_tmp-file-root-cause-summary.md` (this file)
- **Standards**: status-markers.md, artifact-management.md, tasks.md

---

## Overview

Task 574 fixed bare `mktemp` calls in shell scripts but missed the documentation layer where LLM agents read patterns and replicate them. This task standardized all temp file references across 26 files in two repositories (`~/.config/nvim/.opencode/` and `~/.dotfiles/.opencode/`) to use the canonical `specs/tmp/state.json` pattern, and added an explicit `/tmp/` prohibition to both AGENTS.md files. The fix eliminates the root cause of `/tmp/state.json.tmp` generation by LLM agents: inconsistent patterns in skill, command, context, and example documentation files.

## What Changed

- `~/.config/nvim/.opencode/AGENTS.md` — Added explicit `/tmp/` prohibition and canonical `specs/tmp/` temp file convention
- `~/.dotfiles/.opencode/AGENTS.md` — Same prohibition added
- `~/.config/nvim/.opencode/docs/examples/research-flow-example.md` — Fixed bare `state.json > state.json.tmp` (no `specs/` prefix) to `specs/state.json > specs/tmp/state.json`
- `~/.config/nvim/.opencode/commands/review.md` — Fixed 3 in-place patterns (state.json and reviews/state.json); added `mkdir -p specs/tmp` guards
- `~/.config/nvim/.opencode/commands/todo.md` — Fixed 4 in-place patterns (state.json and archive/state.json); added `mkdir -p specs/tmp` guards
- `~/.config/nvim/.opencode/skills/skill-project-overview/SKILL.md` — Fixed 1 in-place pattern; added `mkdir -p specs/tmp` guard
- `~/.config/nvim/.opencode/skills/skill-todo/SKILL.md` — Fixed 5 in-place patterns; added `mkdir -p specs/tmp` guard
- `~/.config/nvim/.opencode/skills/skill-tag/SKILL.md` — Fixed 2 `${state_file}.tmp` variable expansion patterns; added `mkdir -p specs/tmp` guard
- `~/.config/nvim/.opencode/context/workflows/preflight-postflight.md` — Fixed 1 hybrid `specs/tmp/state.json.tmp` pattern
- `~/.config/nvim/.opencode/context/core/workflows/preflight-postflight.md` — Fixed 1 hybrid pattern
- `~/.config/nvim/.opencode/context/core/patterns/jq-escaping-workarounds.md` — Fixed 1 `specs/tmp/test-specs/state.json.tmp` pattern
- `~/.config/nvim/.opencode/extensions/core/` (7 files) — Same fixes as primary files above
- `~/.config/nvim/.opencode/extensions/web/skills/skill-tag/SKILL.md` — Fixed 2 variable expansion patterns
- `~/.dotfiles/.opencode/` (7 files) — Same fixes as nvim primary files

## Decisions

- Used `specs/tmp/reviews-state.json` as the temp filename for `specs/reviews/state.json` writes to avoid any ambiguity with `specs/tmp/state.json` (different source file, different temp name)
- Used `specs/tmp/archive-state.json` as the temp filename for `specs/archive/state.json` writes for the same reason
- For the test example in `jq-escaping-workarounds.md`, used `specs/tmp/test-specs/state-updated.json` to avoid a nested `.tmp` suffix in a `specs/tmp/` subdirectory
- Added `mkdir -p specs/tmp` as a separate line before jq writes (not inline) to ensure clarity and correctness
- The AGENTS.md prohibition was added after the existing Rules and Conventions table as a standalone bold paragraph for visibility

## Plan Deviations

- None (implementation followed plan)

## Impacts

- LLM agents reading skill, command, and context files will now see consistent `specs/tmp/` patterns everywhere, reducing the probability of generating `/tmp/` paths
- AGENTS.md prohibition provides an upfront constraint that is loaded at every session start
- The `external_directory: "ask"` permission prompt for `/tmp/*` should no longer appear when running `/research` or similar commands in OpenCode
- All atomic write patterns now include `mkdir -p specs/tmp` guards, preventing failures if `specs/tmp/` does not yet exist

## Follow-ups

- Consider adding a lint check to `validate-wiring.sh` (or a new script) that greps for `> /tmp/` in `.opencode/skills/`, `.opencode/commands/`, and `.opencode/agent/` directories to catch future regressions automatically (per research report Priority 4 recommendation)

## References

- `specs/578_fix_opencode_tmp_file_usage_root_cause/reports/01_tmp-file-root-cause.md`
- `specs/578_fix_opencode_tmp_file_usage_root_cause/plans/01_tmp-file-root-cause.md`
- Task 574 artifacts: `specs/574_fix_temp_file_usage_opencode_agent_system/`
