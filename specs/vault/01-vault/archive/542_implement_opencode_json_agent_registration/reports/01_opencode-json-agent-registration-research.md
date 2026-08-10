# Research Report: Task #542 - Implement opencode.json Agent Registration

- **Task**: 542 - implement_opencode_json_agent_registration
- **Started**: 2026-05-07
- **Status**: [RESEARCHING]
- **Dependencies**: 540 (completed), 541 (completed)
- **Sources/Inputs**:
  - `specs/540_research_opencode_json_and_extension_gaps/reports/01_opencode-json-research.md`
  - `specs/540_research_opencode_json_and_extension_gaps/plans/01_opencode-json-plan.md`
  - `specs/540_research_opencode_json_and_extension_gaps/summaries/01_opencode-json-summary.md`
  - `specs/541_design_opencode_json_agent_registration/reports/01_opencode-json-agent-registration-design.md`
  - `specs/541_design_opencode_json_agent_registration/plans/01_opencode-json-agent-registration-plan.md`
  - `specs/541_design_opencode_json_agent_registration/summaries/01_opencode-json-agent-registration-summary.md`
  - `lua/neotex/plugins/ai/shared/extensions/merge.lua`
  - `lua/neotex/plugins/ai/shared/extensions/init.lua`
  - `lua/neotex/plugins/ai/shared/extensions/verify.lua`
  - `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
  - `lua/neotex/plugins/ai/opencode/core/init.lua`
  - `lua/neotex/plugins/ai/opencode.lua`
  - `.opencode/extensions/*/manifest.json` (16 extensions)
  - `.opencode/extensions/*/opencode-agents.json` (14 fragments)
  - `.opencode/templates/opencode.json`
- **Artifacts**: `specs/542_implement_opencode_json_agent_registration/reports/01_opencode-json-agent-registration-research.md`

## Executive Summary

**The core automatic agent registration infrastructure was fully implemented by Task 540.** All 14 agent-providing extensions now have `opencode-agents.json` fragments and `merge_targets.opencode_json` declarations in their manifests. The extension loader's `process_merge_targets()` and `reverse_merge_targets()` functions correctly merge and unmerge agent definitions into the project's `opencode.json`. Pre-merge validation of `{file:...}` references exists and aborts merge on missing files.

**Task 542's scope is to close the 4 implementation gaps identified and designed by Task 541:**

1. **Cleanup is never triggered**: `cleanup_stale_opencode_agents()` exists in `init.lua` but is never called on startup, after load, or after unload.
2. **No conflict detection**: When two extensions define the same agent name, the first-loaded wins silently; unloading the winner orphans the second extension's expectation.
3. **No fragment-to-manifest consistency check**: `verify.lua` does not verify that agents declared in a manifest's `provides.agents` match the extension's `opencode-agents.json` fragment.
4. **Sync ignores managed sidecar**: `sync.lua` does not check the `.opencode.json.managed` sidecar before deciding whether to overwrite `opencode.json`.

## Current Extension Loader Architecture

### Load Cycle

```
manager.load(extension_name)
  -> loader.copy_simple_files()           -- copies agent .md files
  -> loader.copy_manifest()               -- copies manifest.json
  -> process_merge_targets()
     -> merge_mod.merge_opencode_agents() -- merges agent defs into opencode.json
        -> validate_opencode_fragment()   -- validates {file:...} refs exist
        -> reads/writes opencode.json
        -> tracks added keys in {keys = {...}}
     -> state tracks merged_sections.opencode_json
  -> state_mod.mark_loaded()              -- persists to extensions.json
  -> verify_mod.verify_extension()        -- post-load verification
```

### Unload Cycle

```
manager.unload(extension_name)
  -> state_mod.read()                     -- gets merged_sections
  -> reverse_merge_targets()
     -> merge_mod.unmerge_opencode_agents() -- removes tracked keys only
  -> loader.remove_installed_files()      -- deletes copied files
  -> state_mod.mark_unloaded()            -- updates extensions.json
```

### Key Code Locations

| Function | File | Lines | Status |
|----------|------|-------|--------|
| `merge_opencode_agents()` | `merge.lua` | 699-755 | Implemented, needs conflict detection |
| `unmerge_opencode_agents()` | `merge.lua` | 762-787 | Implemented |
| `validate_opencode_fragment()` | `merge.lua` | 668-689 | Implemented |
| `process_merge_targets()` | `init.lua` | 100-148 | Implemented, calls merge |
| `reverse_merge_targets()` | `init.lua` | 150-186 | Implemented, calls unmerge |
| `cleanup_stale_opencode_agents()` | `init.lua` | 845-888 | Implemented, **never called** |
| `verify_extension()` | `verify.lua` | 284-405 | Implemented, needs opencode_json check |
| `sync_files()` | `sync.lua` | 332-414 | Implemented, needs managed flag check |

## opencode.json Structure

The `opencode.json` file at project root defines agents for the OpenCode CLI:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "default_agent": "build",
  "agent": {
    "agent-name": {
      "description": "Human-readable description",
      "mode": "subagent",
      "prompt": "{file:.opencode/agent/subagents/name-agent.md}",
      "tools": {"read": true, "write": true, ...}
    }
  }
}
```

The `prompt` field supports `{file:PATH}` placeholders resolved at CLI startup. Missing files cause CLI crashes.

## Extension Manifest Format

All 14 agent-providing extensions declare `merge_targets.opencode_json`:

```json
{
  "merge_targets": {
    "opencode_json": {
      "source": "opencode-agents.json",
      "target": "opencode.json"
    }
  }
}
```

Extensions with agents: `core`, `filetypes`, `founder`, `formal`, `latex`, `lean`, `nix`, `nvim`, `present`, `python`, `typst`, `web`, `z3`, `epidemiology`.

Extensions without agents: `memory`, `slidev`.

## Existing Agent Registration Patterns

### Fragment Format (opencode-agents.json)

Standardized by Task 540:
- Agent name = filename without `-agent.md` suffix
- Description = extracted from agent frontmatter `description` field
- Mode = `"subagent"` for all extension agents
- Prompt = `{file:.opencode/agent/subagents/{agent-name}-agent.md}`
- Tools determined by agent name suffix:
  - Research agents: `read`, `write`, `edit`, `glob`, `grep`, `bash`, `webfetch`, `websearch`
  - Implementation agents: `write`, `edit`, `bash`, `read`, `glob`, `grep`
  - Router agents: `read`, `grep`, `glob`
  - Other agents: full toolset

### Merge/Unmerge Pattern

The key-based JSON merge tracking pattern is used:
- **Merge**: Adds keys that don't exist; tracks added keys in `{keys = {...}}`
- **Unmerge**: Removes only tracked keys; preserves user additions and other extensions' agents
- **State**: Persisted across sessions in `extensions.json` under `merged_sections.opencode_json`

## Findings

### Finding 1: Core Infrastructure Is Complete and Functional

Task 540 implemented all core infrastructure:
- 14 `opencode-agents.json` fragments created
- 14 extension manifests updated with `merge_targets.opencode_json`
- `opencode.json` added to sync root files with merge-only semantics
- Pre-merge validation prevents corrupting `opencode.json` with missing `{file:...}` references
- `cleanup_stale_opencode_agents()` function exists for defense-in-depth

The merge code path IS exercised when extensions load: `init.lua` line 123 checks `config.merge_target_key == "opencode_md"` (true for OpenCode) and `ext_manifest.merge_targets.opencode_json` (true for all 14 agent-providing extensions).

### Finding 2: Cleanup Function Exists But Is Never Called

`cleanup_stale_opencode_agents()` in `init.lua` (lines 845-888) scans `opencode.json` for `{file:...}` references pointing to missing files, removes stale entries, and notifies the user. However, it is never invoked:

- **Not called on Neovim startup**: `opencode.lua` `config()` (line 34-70) does not call it
- **Not called after extension load**: `manager.load()` exits at line 549 without calling it
- **Not called after extension unload**: `manager.unload()` exits at line 676 without calling it
- **Not called on picker open**: No hook in `OpencodeExtensions` command

**TODO(541) annotations exist at:**
- `init.lua` line 545: "Call cleanup_stale_opencode_agents(project_dir) here after successful load"
- `init.lua` line 672: "Call cleanup_stale_opencode_agents(project_dir) here after successful unload"

**Implementation approach**: Add `manager.cleanup_stale_opencode_agents(project_dir)` calls:
1. In `opencode.lua` `config()` after server setup
2. In `manager.load()` after successful load (line 548)
3. In `manager.unload()` after successful unload (line 675)

### Finding 3: Conflict Detection Is Not Implemented

When two extensions define the same agent name, the current behavior is silent skip:

```lua
-- merge.lua line 732-742
for key, value in pairs(source_agents) do
  if target.agent[key] == nil then
    target.agent[key] = value
    table.insert(added_keys, key)
  else
    -- TODO(541): Implement conflict detection before skipping existing agent key.
  end
end
```

**Scenario**: Extension A defines agent `"grant"`. Extension B also defines `"grant"`.
1. Load A: `"grant"` added, tracked under A
2. Load B: `"grant"` already exists, skipped silently
3. Unload A: `"grant"` removed
4. B is still loaded but its agent is missing from `opencode.json`

**Implementation approach**: Before skipping an existing key, check `extensions.json` to find which extension owns it. If owned by a different extension, emit a warning:

```lua
-- Pseudocode for conflict detection
local state = state_mod.read(project_dir, config)
local loaded = state_mod.list_loaded(state)
for _, ext_name in ipairs(loaded) do
  local ext_sections = state_mod.get_merged_sections(state, ext_name)
  if ext_sections.opencode_json and vim.tbl_contains(ext_sections.opencode_json.keys, key) then
    -- Conflict: agent 'key' owned by extension 'ext_name'
    -- Warn user and skip
  end
end
```

**File**: `merge.lua`, around line 737.

### Finding 4: Fragment-to-Manifest Consistency Verification Missing

`verify.lua` `verify_extension()` checks agents exist on disk, skills exist, rules exist, etc., but does NOT verify that the `opencode-agents.json` fragment matches `manifest.provides.agents`.

**TODO(541) annotation at `verify.lua` line 285**:
```lua
-- TODO(541): Implement verify_opencode_json_merge() for fragment-to-manifest consistency.
-- Check: every manifest.provides.agents entry has matching opencode-agents.json entry (and vice versa).
```

**Implementation approach**: Add `verify_opencode_json_merge()` function that:
1. Reads the extension's `opencode-agents.json`
2. Compares agent names against `manifest.provides.agents`
3. Reports mismatches as verification errors
4. Called from `verify_extension()` after existing checks

**File**: `verify.lua`, around line 285.

### Finding 5: Sync Does Not Respect Managed Sidecar

`sync.lua` handles `opencode.json` as a root file with merge-only semantics (skip if exists). However, it does not check the `.opencode.json.managed` sidecar before deciding whether to overwrite.

**TODO(541) annotation at `sync.lua` line 340**:
```lua
-- TODO(541): Respect .managed sidecar before deciding skip for opencode.json.
-- Decision 4 from specs/541_design_opencode_json_agent_registration/designs/01_agent-registration-design-spec.md
-- If opencode.json is unmanaged, always skip (do not overwrite user customizations).
```

**Implementation approach**: In `sync_files()` for `opencode.json`:
1. Check for `.opencode.json.managed` before deciding action
2. If unmanaged and file exists, change action to "skip" (or stronger: never touch)
3. If managed, proceed with current behavior

**File**: `sync.lua`, around line 340 and 899.

### Finding 6: Base Template Is Missing Agents Added by Task 540

The base template at `.opencode/templates/opencode.json` contains 7 core agents but is missing agents added during Task 540: `reviser` and `spawn` (both in `core/manifest.json` `provides.agents`).

**Core manifest agents**: `code-reviewer-agent.md`, `general-implementation-agent.md`, `general-research-agent.md`, `meta-builder-agent.md`, `planner-agent.md`, `reviser-agent.md`, `spawn-agent.md`

**Base template agents**: `build`, `plan`, `task-planner`, `general-research`, `general-implementation`, `meta-builder`, `code-reviewer`

The template is missing:
- `reviser` (from `reviser-agent.md`)
- `spawn` (from `spawn-agent.md`)

Note: The `core` extension's `opencode-agents.json` fragment correctly includes all 7 agents. When core is loaded, the merge adds `reviser` and `spawn` to `opencode.json`. However, on a fresh project where core is not yet loaded, the base template would be incomplete if these agents are expected to be available.

**Recommendation**: Update `.opencode/templates/opencode.json` to include `reviser` and `spawn` agents, matching the core extension's fragment.

### Finding 7: No Agent Name Registry Enforcement

Task 541 created `.opencode/context/reference/agent-name-registry.md` documenting reserved names and naming conventions, but there is no runtime enforcement. Two extensions could still define the same agent name, and the conflict would only be detected at load time (if Finding 3 is implemented).

**Recommendation for task 542**: Implement conflict detection (Finding 3) as the runtime enforcement mechanism. The registry document serves as human-readable guidance; runtime validation catches violations.

## Implementation Recommendations

### Priority 1: Wire Cleanup to Automatic Triggers

**Files**: `lua/neotex/plugins/ai/opencode.lua`, `lua/neotex/plugins/ai/shared/extensions/init.lua`

1. In `opencode.lua` `config()` (after line 59), add:
   ```lua
   local ext_manager = require("neotex.plugins.ai.shared.extensions")
   ext_manager.cleanup_stale_opencode_agents()
   ```

2. In `init.lua` `manager.load()` (after line 548), add:
   ```lua
   manager.cleanup_stale_opencode_agents(project_dir)
   ```

3. In `init.lua` `manager.unload()` (after line 675), add:
   ```lua
   manager.cleanup_stale_opencode_agents(project_dir)
   ```

### Priority 2: Implement Conflict Detection in merge_opencode_agents

**File**: `lua/neotex/plugins/ai/shared/extensions/merge.lua` (around line 737)

Before skipping an existing agent key, read `extensions.json` to find the owning extension. Emit a warning notification. The state module functions needed are already available: `state_mod.read()`, `state_mod.list_loaded()`, `state_mod.get_merged_sections()`.

### Priority 3: Add verify_opencode_json_merge to verify.lua

**File**: `lua/neotex/plugins/ai/shared/extensions/verify.lua` (around line 285)

Add a new verification step that compares `manifest.provides.agents` (stripping `-agent.md` suffixes) against `opencode-agents.json` agent keys. Report mismatches in `verification.errors`.

### Priority 4: Respect Managed Sidecar in Sync

**File**: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (around lines 340, 899)

Import or replicate `is_managed()` logic from `opencode/core/init.lua`. For `opencode.json`, if `.opencode.json.managed` sidecar does not exist, always use "skip" action (never overwrite).

### Priority 5: Update Base Template

**File**: `.opencode/templates/opencode.json`

Add missing `reviser` and `spawn` agents to match the core extension's fragment.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Cleanup on startup slows Neovim init | Low | Medium | Cleanup is fast (single file read + scan); only writes if stale entries found |
| Conflict detection causes false positives | Low | Medium | Only warns on actual key collisions; does not block load |
| verify_opencode_json_merge breaks existing verification | Low | Medium | Add as non-fatal warning (not failed status) to avoid breaking working extensions |
| Managed sidecar sync change breaks existing workflows | Medium | Low | Current behavior already skips existing opencode.json; managed check is additive safety |

## Files to Modify for Implementation

| File | Change | Priority |
|------|--------|----------|
| `lua/neotex/plugins/ai/opencode.lua` | Add cleanup call in `config()` | P1 |
| `lua/neotex/plugins/ai/shared/extensions/init.lua` | Add cleanup calls in `load()` and `unload()`; remove TODO(541) comments | P1 |
| `lua/neotex/plugins/ai/shared/extensions/merge.lua` | Implement conflict detection; remove TODO(541) comment | P2 |
| `lua/neotex/plugins/ai/shared/extensions/verify.lua` | Add `verify_opencode_json_merge()`; call from `verify_extension()`; remove TODO(541) comment | P3 |
| `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` | Check `.managed` sidecar for opencode.json; remove TODO(541) comment | P4 |
| `.opencode/templates/opencode.json` | Add `reviser` and `spawn` agents | P5 |

## References

- Task 540 Research: `specs/540_research_opencode_json_and_extension_gaps/reports/01_opencode-json-research.md`
- Task 540 Plan: `specs/540_research_opencode_json_and_extension_gaps/plans/01_opencode-json-plan.md`
- Task 541 Design: `specs/541_design_opencode_json_agent_registration/reports/01_opencode-json-agent-registration-design.md`
- Task 541 Plan: `specs/541_design_opencode_json_agent_registration/plans/01_opencode-json-agent-registration-plan.md`
- Design Spec: `specs/541_design_opencode_json_agent_registration/designs/01_agent-registration-design-spec.md`
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` (lines 662-787)
- `lua/neotex/plugins/ai/shared/extensions/init.lua` (lines 100-186, 503-675, 838-888)
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` (lines 284-405)
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (lines 260-284, 332-414, 869-914)
- `lua/neotex/plugins/ai/opencode/core/init.lua` (lines 50-143)
- `.opencode/context/reference/opencode-json-lifecycle.md`
- `.opencode/context/patterns/json-merge-tracking.md`
