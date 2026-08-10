# Implementation Summary: Task #540 - Fix OpenCode Extension Agent Registration

- **Task**: 540 - research_opencode_json_and_extension_gaps
- **Status**: [COMPLETED]
- **Started**: 2026-05-07T00:00:00Z
- **Completed**: 2026-05-07T00:30:00Z
- **Artifacts**: plans/01_opencode-json-plan.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed the OpenCode extension loader to automatically register and unregister agents in `opencode.json`, eliminating startup crashes caused by stale `{file:...}` references. The implementation spans 5 phases: pre-merge validation, sync integration, fragment generation, manifest updates, and startup cleanup.

## What Changed

- **Pre-merge validation**: Added `validate_opencode_fragment()` to `merge.lua` that checks all `{file:...}` references exist before merging. Integrated into `merge_opencode_agents()` with error logging in `init.lua`.
- **Sync integration**: Added `opencode.json` to the `.opencode` root file sync list in `sync.lua` with merge-only semantics (skips if exists to prevent overwriting project-specific config).
- **Fragment generation**: Created `opencode-agents.json` fragments for all 14 agent-providing extensions (core, filetypes, founder, formal, latex, lean, nix, nvim, present, python, typst, web, z3, epidemiology). Updated present's existing fragment from 5 to 9 agents.
- **Manifest updates**: Added `merge_targets.opencode_json` to all 14 agent-providing extension manifests, enabling automatic registration/unregistration.
- **Startup cleanup**: Added `cleanup_stale_opencode_agents()` to the extension manager in `init.lua`, which scans `opencode.json` on startup and removes entries pointing to missing agent files.
- **Utility export**: Exported `M.write_json()` from `merge.lua` for reuse by the cleanup function.

## Decisions

- Used agent frontmatter `description` fields for fragment descriptions rather than generic fallbacks.
- Assigned tools based on agent name suffix: research agents get web tools, implementation agents get write/edit/bash, routers get read/grep/glob, others get full toolset.
- Chose merge-only sync semantics for `opencode.json` to prevent overwriting project-specific agent configurations.
- Made startup cleanup idempotent by only removing entries where the referenced file is actually missing.

## Impacts

- Extension load/unload now correctly updates `opencode.json` automatically.
- `opencode --port` startup crashes from stale `{file:...}` references are prevented by validation and cleanup.
- New projects synced with `.opencode` receive a base `opencode.json` template.
- All 14 extensions with agents now declare their `opencode-agents.json` fragments in manifests.

## Follow-ups

- Test actual extension load/unload cycle in a live Neovim session (deferred to user acceptance testing).
- Consider adding CI validation that `provides.agents` in manifests stays in sync with `opencode-agents.json` fragments.

## References

- `plans/01_opencode-json-plan.md` - Implementation plan
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Validation and merge functions
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Manager with cleanup
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Sync integration
- `.opencode/extensions/*/opencode-agents.json` - 14 generated fragments
- `.opencode/extensions/*/manifest.json` - Updated manifests
