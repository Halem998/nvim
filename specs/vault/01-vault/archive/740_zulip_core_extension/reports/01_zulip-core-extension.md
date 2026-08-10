# Research Report: Task #740

**Task**: 740 - Add /zulip command and skill-zulip to core extension
**Started**: 2026-06-17T00:00:00Z
**Completed**: 2026-06-17T00:01:00Z
**Effort**: 15 minutes
**Dependencies**: None
**Sources/Inputs**: Codebase exploration
**Artifacts**: specs/740_zulip_core_extension/reports/01_zulip-core-extension.md
**Standards**: report-format.md

## Executive Summary

- The `/zulip` command (`zulip.md`) and `skill-zulip` (`SKILL.md`) exist only in `.claude/commands/` and `.claude/skills/` respectively — not in the core extension
- Adding them to the core extension requires copying the files into `extensions/core/commands/` and `extensions/core/skills/`, then declaring them in `manifest.json`
- The skill has no external script dependencies — it uses only `curl`, `jq`, and `python3` (all standard OS tools)
- No context index entries or CLAUDE.md merge-source changes are required

## Context & Scope

The task is to promote the `/zulip` command and `skill-zulip` from the top-level `.claude/` directory into the `core` extension so they are installed automatically in all child projects (e.g., cslib) when the extension loader runs.

The core extension lives at `.claude/extensions/core/` and is installed via `install-extension.sh`, which creates symlinks from `.claude/commands/` -> `extensions/core/commands/` and `.claude/skills/skill-zulip` -> `extensions/core/skills/skill-zulip`.

## Findings

### Codebase Patterns

**Existing artifact locations**:
- `.claude/commands/zulip.md` — the `/zulip` slash command (50 lines)
- `.claude/skills/skill-zulip/SKILL.md` — the execution skill (227 lines)

The `skill-zulip` directory contains a single file: `SKILL.md`. There are no accompanying shell scripts or helper files — the skill instructs the agent to run bash commands inline.

**Core extension structure**:
- Commands in `extensions/core/commands/` are declared in `provides.commands` in `manifest.json`
- Skills in `extensions/core/skills/` are declared in `provides.skills` in `manifest.json`
- Both are installed as symlinks by `install-extension.sh` when the core extension is installed in a child project

**`install-extension.sh` behavior** (lines 76-143):
- `install_commands()`: iterates `extensions/core/commands/*.md`, creates symlinks at `.claude/commands/<name>`
- `install_skills()`: iterates `extensions/core/skills/skill-*`, creates symlinks at `.claude/skills/<name>`
- The manifest `provides.commands` and `provides.skills` arrays declare what exists in the extension directory, enabling manifest validation

**Current core manifest** (`extensions/core/manifest.json`):
- `provides.commands` currently lists 16 commands (errors.md through project-overview.md) — `zulip.md` is absent
- `provides.skills` currently lists 18 skills (skill-fix-it through skill-project-overview) — `skill-zulip` is absent

**EXTENSION.md**: The README at `extensions/core/EXTENSION.md` references counts (14 commands, 16 skills in text). These counts are informational prose and will need updating too, but are not load-bearing for installation.

**No CLAUDE.md merge-source changes needed**: The `/zulip` command is a standalone utility and does not require a section in the core CLAUDE.md merge-sources. Other simple commands (e.g., `spawn.md`, `tag.md`) are also absent from the merge-sources prose.

**No context index changes needed**: `skill-zulip` has no context files to index. The `index-entries.json` file does not need a new entry.

### Skill Dependencies

`skill-zulip/SKILL.md` depends on:
- `curl` — HTTP client for Zulip API calls
- `jq` — JSON processing
- `python3` — URL decoding and JSON serialization

These are all standard system tools, not Claude Code scripts. No `.claude/scripts/` dependency.

### What Changed in Task 739

Task 739 (specs/739_zulip_fetch_skill/) created the top-level `zulip.md` command and `skill-zulip/SKILL.md` files. Task 740 is a follow-up to register them in the core extension so they propagate to child projects.

## Decisions

- Copy (not symlink) the source files into the extension directory: `extensions/core/commands/zulip.md` and `extensions/core/skills/skill-zulip/SKILL.md`
- Add `"zulip.md"` to `provides.commands` in `manifest.json` (insert alphabetically after `"todo.md"`)
- Add `"skill-zulip"` to `provides.skills` in `manifest.json` (insert alphabetically after `"skill-todo"`)
- Update EXTENSION.md command and skill counts from 14->15 and 16->17 (informational only, not load-bearing)

## Risks & Mitigations

- **Duplicate files**: After the core extension is installed in child projects, there will be a symlink to the extension copy AND potentially the directly-placed files. The existing `zulip.md` and `skill-zulip/` in `.claude/commands/` and `.claude/skills/` in this (nvim) repo act as the source of truth. When `install-extension.sh` runs in a child project like cslib, it will symlink from the extension directory — no conflict.
- **EXTENSION.md count**: Counts in the EXTENSION.md README are prose-only and do not affect installation. Update them for accuracy but they are not blocking.

## Implementation Plan (for planner reference)

### Phase 1: Copy files into extension

1. Copy `.claude/commands/zulip.md` -> `.claude/extensions/core/commands/zulip.md`
2. Copy `.claude/skills/skill-zulip/SKILL.md` -> `.claude/extensions/core/skills/skill-zulip/SKILL.md`

### Phase 2: Update manifest.json

In `.claude/extensions/core/manifest.json`:
- Add `"zulip.md"` to `provides.commands` array (after `"todo.md"`)
- Add `"skill-zulip"` to `provides.skills` array (after `"skill-todo"`)

### Phase 3: Update EXTENSION.md (optional but recommended)

Update count references in `extensions/core/EXTENSION.md` from 14 commands to 15, and 16 skills to 17.

## Context Extension Recommendations

None. This is a meta task and the change is mechanical (file copies + JSON array entries).

## Appendix

### Files Examined

- `/home/benjamin/.config/nvim/.claude/commands/zulip.md` — 50 lines
- `/home/benjamin/.config/nvim/.claude/skills/skill-zulip/SKILL.md` — 227 lines
- `/home/benjamin/.config/nvim/.claude/extensions/core/manifest.json` — 181 lines
- `/home/benjamin/.config/nvim/.claude/extensions/core/EXTENSION.md` — 50+ lines
- `/home/benjamin/.config/nvim/.claude/scripts/install-extension.sh` — install mechanics
- `/home/benjamin/.config/nvim/.claude/extensions/core/merge-sources/claudemd.md` — no zulip section needed
- `/home/benjamin/.config/nvim/.claude/extensions/core/index-entries.json` — no zulip entry needed
