# Implementation Plan: Manage opencode.json via Extension System

- **Task**: 183 - Manage opencode.json via extension system
- **Status**: [COMPLETED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

The extension system manages AGENTS.md, settings.json, and index.json but does not manage opencode.json. Agent definitions referencing `{file:...}` paths break when extensions are loaded/unloaded because opencode.json retains stale references. This plan adds a new `opencode_json` merge target type that merges/unmerges agent definitions into opencode.json during extension lifecycle events, plus a base template installed by the core loader.

### Research Integration

Research report research-001.md identified the existing merge infrastructure patterns (section injection, deep merge, index append) and proposed a new `opencode_json` merge target using tracked-key merge/unmerge. The plan follows these recommendations with adjustments for the existing code structure.

## Goals & Non-Goals

**Goals**:
- Add `merge_opencode_agents` and `unmerge_opencode_agents` functions to merge.lua
- Wire `opencode_json` merge target into `process_merge_targets` and `reverse_merge_targets` in init.lua
- Create a base opencode.json template installed by core agent system loader
- Create `opencode-agents.json` files for all extensions that provide agents
- Update each extension's manifest.json with `opencode_json` merge target entry
- Add `_managed_by` marker for managed-state detection and backup strategy

**Non-Goals**:
- Merging `command` or `tools` sections (agent-only scope for now)
- Changing existing merge strategies for AGENTS.md, settings.json, or index.json
- Supporting opencode.json for Claude-specific extensions (Claude uses different config)

## Risks & Mitigations

- **Risk**: Existing user-edited opencode.json overwritten on core load. **Impact**: H. **Likelihood**: M. **Mitigation**: Check for `_managed_by` marker; backup to `opencode.json.user-backup` if not managed.
- **Risk**: Agent key collisions between extensions. **Impact**: L. **Likelihood**: L. **Mitigation**: Extension agent keys are namespaced (e.g., `web-research`, `lean-research`); skip-if-exists semantics prevent overwrite.
- **Risk**: JSON formatting inconsistency after merge. **Impact**: L. **Likelihood**: M. **Mitigation**: Reuse existing `write_json` function with jq pretty-printing.

## Implementation Phases

### Phase 1: Add merge/unmerge functions to merge.lua [COMPLETED]

**Goal:** Implement the core merge infrastructure for opencode.json agent definitions.

**Tasks:**
- [ ] Add `merge_opencode_agents(target_path, fragment)` function to merge.lua
  - Read target opencode.json (create with empty agent object if missing)
  - For each key in `fragment.agent`, add to target if key does not exist
  - Track added keys for unmerge
  - Write updated JSON with `write_json`
  - Return success and tracked keys `{keys = {...}}`
- [ ] Add `unmerge_opencode_agents(target_path, tracked)` function to merge.lua
  - Read target opencode.json
  - Remove agent keys listed in `tracked.keys`
  - Write updated JSON
  - Return success
- [ ] Verify both functions handle edge cases: missing file, empty agent section, nil tracked data

**Timing:** 30 minutes

**Files to modify:**
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Add two new functions

**Verification:**
- Functions follow the same pattern as `merge_settings`/`unmerge_settings`
- Edge cases handled (nil inputs, missing file, empty objects)

---

### Phase 2: Wire opencode_json into init.lua merge processing [COMPLETED]

**Goal:** Connect the new merge functions to the extension load/unload lifecycle.

**Tasks:**
- [ ] Add `opencode_json` processing block in `process_merge_targets()` after the index.json block
  - Read source file from `mt_config.source` path
  - Call `merge_mod.merge_opencode_agents(target_path, fragment)`
  - Store tracked data in `merged_sections.opencode_json`
- [ ] Add `opencode_json` reverse block in `reverse_merge_targets()` after the index reverse block
  - Check `merged_sections.opencode_json` exists
  - Call `merge_mod.unmerge_opencode_agents(target_path, merged_sections.opencode_json)`
- [ ] Handle the target path: use `project_dir .. "/" .. mt_config.target` (opencode.json is at project root, not inside .opencode/)

**Timing:** 30 minutes

**Files to modify:**
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Add opencode_json blocks in two functions

**Verification:**
- Loading an extension with `opencode_json` merge target adds agent keys to opencode.json
- Unloading removes only the tracked keys

---

### Phase 3: Create base opencode.json template and update core loader [COMPLETED]

**Goal:** Install a base opencode.json with core agent definitions when the OpenCode core system loads.

**Tasks:**
- [ ] Create base template file at `.opencode/templates/opencode.json` with:
  - `_managed_by: "neotex-extensions"` and `_managed_version: "1.0.0"` markers
  - `$schema` field
  - `default_agent` set to `"build"`
  - Core agent definitions: `build`, `plan`, `task-planner`, `general-research`, `general-implementation`, `meta-builder`, `code-reviewer`
  - `command` and `tools` sections from current known structure
- [ ] Extract current core agent definitions from the existing opencode agent files to populate the template prompts with `{file:...}` references
- [ ] Update the OpenCode core loader to install base opencode.json:
  - Check if opencode.json exists at project root
  - If exists and no `_managed_by` field: backup to `opencode.json.user-backup`, then install template
  - If exists and has `_managed_by`: install template (overwrite managed file)
  - If not exists: install template
- [ ] Identify and update the correct loader file (likely in `lua/neotex/plugins/ai/opencode/` or a setup function)

**Timing:** 1 hour

**Files to modify:**
- `.opencode/templates/opencode.json` - New file (base template)
- Core OpenCode loader file (to be identified) - Add template installation logic

**Verification:**
- Base template is valid JSON with all required fields
- Backup is created when overwriting unmanaged file
- Managed file detection works via `_managed_by` field

---

### Phase 4: Create opencode-agents.json for all extensions [COMPLETED]

**Goal:** Create agent definition files and update manifests for all 11 extensions that provide agents.

**Tasks:**
- [ ] For each extension (epidemiology, filetypes, formal, latex, lean, nix, nvim, python, typst, web, z3):
  - Create `opencode-agents.json` in the extension directory with agent definitions
  - Each agent entry needs: description, mode ("subagent"), prompt (`{file:...}` reference), and tools
  - Agent keys should be descriptive and namespaced (e.g., `web-research`, `lean-implementation`)
- [ ] Update each extension's `manifest.json` to add `opencode_json` merge target:
  ```json
  "opencode_json": {
    "source": "opencode-agents.json",
    "target": "opencode.json"
  }
  ```
- [ ] Read existing agent files from each extension to determine correct `{file:...}` paths and tool configurations

**Timing:** 1.5 hours

**Files to modify:**
- `.claude/extensions/epidemiology/opencode-agents.json` - New file
- `.claude/extensions/epidemiology/manifest.json` - Add opencode_json target
- `.claude/extensions/filetypes/opencode-agents.json` - New file
- `.claude/extensions/filetypes/manifest.json` - Add opencode_json target
- `.claude/extensions/formal/opencode-agents.json` - New file
- `.claude/extensions/formal/manifest.json` - Add opencode_json target
- `.claude/extensions/latex/opencode-agents.json` - New file
- `.claude/extensions/latex/manifest.json` - Add opencode_json target
- `.claude/extensions/lean/opencode-agents.json` - New file
- `.claude/extensions/lean/manifest.json` - Add opencode_json target
- `.claude/extensions/nix/opencode-agents.json` - New file
- `.claude/extensions/nix/manifest.json` - Add opencode_json target
- `.claude/extensions/nvim/opencode-agents.json` - New file
- `.claude/extensions/nvim/manifest.json` - Add opencode_json target
- `.claude/extensions/python/opencode-agents.json` - New file
- `.claude/extensions/python/manifest.json` - Add opencode_json target
- `.claude/extensions/typst/opencode-agents.json` - New file
- `.claude/extensions/typst/manifest.json` - Add opencode_json target
- `.claude/extensions/web/opencode-agents.json` - New file
- `.claude/extensions/web/manifest.json` - Add opencode_json target
- `.claude/extensions/z3/opencode-agents.json` - New file
- `.claude/extensions/z3/manifest.json` - Add opencode_json target

**Verification:**
- All 11 opencode-agents.json files are valid JSON
- All manifest.json files have the opencode_json merge target
- Agent keys match the naming convention used in AGENTS.md sections

---

### Phase 5: End-to-end verification [COMPLETED]

**Goal:** Validate the full lifecycle: core load, extension load, extension unload, core reload.

**Tasks:**
- [ ] Test core load: verify base opencode.json is installed with core agents
- [ ] Test extension load (e.g., web): verify web agent keys are added to opencode.json
- [ ] Test extension unload: verify web agent keys are removed, core agents preserved
- [ ] Test core reload: verify opencode.json returns to base state
- [ ] Test backup strategy: place a manual opencode.json without `_managed_by`, load core, verify backup created
- [ ] Test idempotency: load same extension twice (should report already loaded)
- [ ] Test multiple extensions: load web + lean, verify both agent sets present, unload one, verify other preserved
- [ ] Run headless Neovim verification: `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.merge')" -c "q"`

**Timing:** 30 minutes

**Files to modify:**
- None (verification only)

**Verification:**
- All lifecycle scenarios produce correct opencode.json state
- No data loss or corruption
- Backup strategy works correctly

## Testing & Validation

- [ ] `merge_opencode_agents` adds agent keys to empty opencode.json
- [ ] `merge_opencode_agents` skips existing keys (no overwrite)
- [ ] `unmerge_opencode_agents` removes only tracked keys
- [ ] `unmerge_opencode_agents` handles missing file gracefully
- [ ] Extension load adds agent definitions to opencode.json
- [ ] Extension unload removes agent definitions from opencode.json
- [ ] Core template installs with `_managed_by` marker
- [ ] Unmanaged file is backed up before template install
- [ ] All 11 extension opencode-agents.json files are valid JSON
- [ ] Headless Neovim loads merge module without errors

## Artifacts & Outputs

- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Updated with opencode_json functions
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Updated with opencode_json merge processing
- `.opencode/templates/opencode.json` - Base template (new file)
- `.claude/extensions/*/opencode-agents.json` - Agent definitions (11 new files)
- `.claude/extensions/*/manifest.json` - Updated manifests (11 files)
- `specs/183_manage_opencode_json_via_extension_system/summaries/implementation-summary-YYYYMMDD.md`

## Rollback/Contingency

- Remove the two new functions from merge.lua and the two new blocks from init.lua to revert merge infrastructure
- Delete `.opencode/templates/opencode.json` to revert core template
- Delete `opencode-agents.json` from each extension directory and remove `opencode_json` entries from manifests
- Restore `opencode.json.user-backup` if user's original file was backed up
- All changes are additive; existing merge targets (AGENTS.md, settings, index) are unaffected
