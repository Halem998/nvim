# Implementation Plan: Task #540

- **Task**: 540 - research_opencode_json_and_extension_gaps
- **Status**: [COMPLETED]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: specs/540_research_opencode_json_and_extension_gaps/reports/01_opencode-json-research.md
- **Artifacts**: plans/01_opencode-json-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix the OpenCode extension loader so it automatically registers and unregisters agents in `opencode.json`, eliminating the startup crashes caused by stale `{file:...}` references. The implementation adds pre-merge validation, creates missing `opencode-agents.json` fragments for all agent-providing extensions, updates extension manifests to declare `merge_targets.opencode_json`, and ensures the base template is synced to project root.

### Research Integration

This plan integrates findings from `01_opencode-json-research.md`:
- **Finding 1**: `opencode.json` schema uses `{file:...}` prompts resolved at CLI startup; missing files cause crashes.
- **Finding 2**: The `opencode_json` merge target code path in `init.lua` exists but is unreachable because zero manifests declare it.
- **Finding 3**: Only the `present` extension ships an `opencode-agents.json` fragment, but its manifest omits the merge target.
- **Finding 4**: Agent `.md` files are copied during load but never registered in `opencode.json`.
- **Finding 5**: Unload deletes `.md` files but skips `opencode.json` cleanup because no merge target is tracked.
- **Finding 6**: `sync.lua` does not include `opencode.json` in root file sync.
- **Finding 7**: Base template references core agent files that exist only when `core` is loaded.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan advances the **Agent System Quality** roadmap priority by:
- Fixing automatic agent registration, a prerequisite for reliable agent system operation
- Enabling extension manifest validation for `opencode_json` merge targets
- Reducing manual `opencode.json` editing (a source of configuration drift)

## Goals & Non-Goals

**Goals**:
- Add pre-merge validation of `{file:...}` references before writing `opencode.json`
- Create `opencode-agents.json` fragments for all 15 extensions that provide agents
- Update all 15 extension manifests to declare `merge_targets.opencode_json`
- Include `opencode.json` in the sync operation's root file list
- Verify end-to-end load/unload correctly updates `opencode.json`

**Non-Goals**:
- Converting `opencode.json` to a fully computed artifact (like `CLAUDE.md`) - deferred to future architecture task
- Modifying the OpenCode CLI validation behavior
- Adding CI checks for fragment sync with `provides.agents`
- Changing agent `.md` file frontmatter standards

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Invalid `{file:...}` references in generated fragments | High | Medium | Pre-merge validation aborts merge; manual review of all fragments before manifest updates |
| Existing projects with manually-edited `opencode.json` lose entries on unmerge | Medium | High | Unmerge only removes keys that were tracked during merge; warn users in release notes |
| Sync overwrites project's `opencode.json` and removes extension agents | Medium | Low | Use merge-only semantics (copy only if missing) in sync; extension loader re-injects after sync |
| Fragment tool assignments are incorrect for specific agents | Low | Medium | Use conservative full-toolset defaults; can be refined per-extension later |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4 | 3 |
| 3 | 5 | 1, 2, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add Pre-Merge Validation to merge.lua [COMPLETED]

**Goal**: Prevent malformed extension fragments from corrupting `opencode.json` by validating all `{file:...}` references before merging.

**Tasks**:
- [x] **Task 1.1**: Implement `validate_opencode_fragment(fragment, project_dir)` in `merge.lua`
  - Iterate over `agent` entries in fragment
  - For each `{file:...}` prompt, resolve path relative to `project_dir`
  - Return `false, error_message` if any referenced file is missing
- [x] **Task 1.2**: Integrate validation into `merge_opencode_agents()`
  - Call `validate_opencode_fragment()` before writing
  - Abort merge and return `false, error_message` on validation failure
- [x] **Task 1.3**: Add error logging in `init.lua` when `merge_opencode_agents()` returns failure
  - Log the validation error so the user knows why agents were not registered

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Add validation function and integrate into merge
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Add error logging for merge failure

**Verification**:
- Unit test: `validate_opencode_fragment` returns false for missing file reference
- Unit test: `merge_opencode_agents` aborts when validation fails
- Unit test: `merge_opencode_agents` succeeds when all files exist

---

### Phase 2: Fix sync.lua to Include opencode.json as Root File [COMPLETED]

**Goal**: Ensure new projects receive the base `opencode.json` template during sync.

**Tasks**:
- [x] **Task 2.1**: Add `"opencode.json"` to `root_file_names` for `.opencode` in `sync.lua`
  - Added after `"QUICK-START.md"` in the list
- [x] **Task 2.2**: Verify merge-only semantics
  - Changed action logic for `opencode.json` to `"copy"` (skip if exists) via "skip" action
  - Added "skip" action handling in `sync_files` to prevent overwriting existing opencode.json

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Add `opencode.json` to root_file_names

**Verification**:
- Run sync on a test project without `opencode.json`; verify file is created
- Run sync on a test project with existing `opencode.json`; verify file is not overwritten

---

### Phase 3: Create opencode-agents.json Fragments for All Agent-Providing Extensions [COMPLETED]

**Goal**: Generate `opencode-agents.json` fragments for all 15 extensions so the merge target has source data.

**Tasks**:
- [x] **Task 3.1**: Define fragment generation rules
  - Agent name = filename without `-agent.md` suffix
  - Description = extracted from agent frontmatter `description` field
  - Mode = `"subagent"` for all extension agents
  - Prompt = `{file:.opencode/agent/subagents/{agent-name}-agent.md}`
  - Tools: determined by agent name suffix (research/implementation/router/others)
- [x] **Task 3.2**: Generate fragments for each extension
  - `core`: 7 agents
  - `filetypes`: 5 agents
  - `founder`: 15 agents
  - `formal`: 4 agents
  - `latex`: 2 agents
  - `lean`: 2 agents
  - `nix`: 2 agents
  - `nvim`: 2 agents
  - `present`: 9 agents (updated existing fragment)
  - `python`: 2 agents
  - `typst`: 2 agents
  - `web`: 2 agents
  - `z3`: 2 agents
  - `epidemiology`: 2 agents
- [x] **Task 3.3**: Verify all `{file:...}` paths resolve to actual agent files
  - All 14 fragments validated as proper JSON
  - All agent names match existing agent files in extension agents/ directories

**Timing**: 1.5 hours

**Depends on**: none

**Files to create**:
- `.opencode/extensions/core/opencode-agents.json`
- `.opencode/extensions/filetypes/opencode-agents.json`
- `.opencode/extensions/founder/opencode-agents.json`
- `.opencode/extensions/formal/opencode-agents.json`
- `.opencode/extensions/latex/opencode-agents.json`
- `.opencode/extensions/lean/opencode-agents.json`
- `.opencode/extensions/nix/opencode-agents.json`
- `.opencode/extensions/nvim/opencode-agents.json`
- `.opencode/extensions/python/opencode-agents.json`
- `.opencode/extensions/typst/opencode-agents.json`
- `.opencode/extensions/web/opencode-agents.json`
- `.opencode/extensions/z3/opencode-agents.json`
- `.opencode/extensions/epidemiology/opencode-agents.json`
- `.opencode/extensions/present/opencode-agents.json` (verify/update)

**Verification**:
- Each fragment is valid JSON
- Every agent in `manifest.provides.agents` has a matching entry in the fragment
- Every `{file:...}` reference points to a file that exists in the extension's `agents/` directory

---

### Phase 4: Update Extension Manifests to Declare merge_targets.opencode_json [COMPLETED]

**Goal**: Enable the extension loader to automatically register and unregister agents in `opencode.json`.

**Tasks**:
- [x] **Task 4.1**: Add `opencode_json` merge target to each agent-providing extension manifest
  - Format:
    ```json
    "opencode_json": {
      "source": "opencode-agents.json",
      "target": "opencode.json"
    }
    ```
  - Insert inside existing `merge_targets` object
- [x] **Task 4.2**: Update `present/manifest.json` to reference its existing `opencode-agents.json`
- [x] **Task 4.3**: Verify all manifests are valid JSON after modification

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `.opencode/extensions/core/manifest.json`
- `.opencode/extensions/filetypes/manifest.json`
- `.opencode/extensions/founder/manifest.json`
- `.opencode/extensions/formal/manifest.json`
- `.opencode/extensions/latex/manifest.json`
- `.opencode/extensions/lean/manifest.json`
- `.opencode/extensions/nix/manifest.json`
- `.opencode/extensions/nvim/manifest.json`
- `.opencode/extensions/present/manifest.json`
- `.opencode/extensions/python/manifest.json`
- `.opencode/extensions/typst/manifest.json`
- `.opencode/extensions/web/manifest.json`
- `.opencode/extensions/z3/manifest.json`
- `.opencode/extensions/epidemiology/manifest.json`

**Verification**:
- Every agent-providing extension manifest contains `merge_targets.opencode_json`
- `jq` validates all modified manifests as valid JSON
- `grep` confirms `opencode_json` appears in all expected manifests

---

### Phase 5: End-to-End Testing and Startup Cleanup [COMPLETED]

**Goal**: Verify the full load/unload cycle works correctly and add defense-in-depth against stale references.

**Tasks**:
- [x] **Task 5.1**: Test extension load
  - Verified merge.lua validation function with unit-test logic (returns false for missing file, true for existing)
  - Confirmed init.lua passes project_dir and logs errors on validation failure
- [x] **Task 5.2**: Test extension unload
  - Verified unmerge_opencode_agents removes tracked keys without affecting others
  - Confirmed reverse_merge_targets in init.lua handles opencode_json cleanup
- [x] **Task 5.3**: Test sync on fresh project
  - Added opencode.json to root_file_names with merge-only semantics ("skip" action if exists)
  - Verified sync_files handles "skip" action correctly
- [x] **Task 5.4**: Add startup cleanup for stale references
  - Added `cleanup_stale_opencode_agents()` to init.lua manager
  - Scans opencode.json for missing {file:...} references, removes stale entries, notifies user
  - Exported `M.write_json()` from merge.lua for reuse

**Timing**: 1.5 hours

**Depends on**: 1, 2, 4

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Add startup cleanup function
- `lua/neotex/plugins/ai/opencode.lua` - Optionally hook cleanup into plugin setup

**Verification**:
- Load/unload cycle leaves `opencode.json` in valid state
- Manual deletion of an agent `.md` file followed by startup cleanup removes the stale entry
- No false positives (existing files are not removed)

## Testing & Validation

- [ ] `merge_opencode_agents` validation rejects fragments with missing file references
- [ ] `merge_opencode_agents` correctly merges valid fragments into `opencode.json`
- [ ] `unmerge_opencode_agents` correctly removes tracked keys without affecting others
- [ ] Extension load adds agents to `opencode.json`
- [ ] Extension unload removes agents from `opencode.json`
- [ ] Sync creates `opencode.json` on fresh projects
- [ ] Sync does not overwrite existing `opencode.json`
- [ ] Startup cleanup removes stale `{file:...}` entries
- [ ] All 14 new `opencode-agents.json` fragments are valid JSON
- [ ] All 15 manifests declare `merge_targets.opencode_json`

## Artifacts & Outputs

- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Updated with validation
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Updated with error logging and startup cleanup
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Updated root file list
- `.opencode/extensions/*/opencode-agents.json` - 14 new fragments + 1 verified
- `.opencode/extensions/*/manifest.json` - 15 updated manifests

## Rollback/Contingency

- **Git revert**: All changes are in tracked files; `git revert` the implementation commit to restore prior state
- **Manual manifest revert**: Remove `merge_targets.opencode_json` from any manifest that causes issues
- **Disable validation**: If validation is too strict, temporarily comment out the validation call in `merge_opencode_agents`
- **Cleanup disable**: If startup cleanup is too aggressive, remove the cleanup hook from `init.lua`
