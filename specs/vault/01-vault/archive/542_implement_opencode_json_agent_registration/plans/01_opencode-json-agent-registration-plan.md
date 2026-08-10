# Implementation Plan: opencode.json Agent Registration Gaps
- **Task**: 542 - implement_opencode_json_agent_registration
- **Status**: [COMPLETED]
- **Effort**: 4 hours
- **Dependencies**: 540 (completed), 541 (completed)
- **Research Inputs**: specs/542_implement_opencode_json_agent_registration/reports/01_opencode-json-agent-registration-research.md
- **Artifacts**: specs/542_implement_opencode_json_agent_registration/plans/01_opencode-json-agent-registration-plan.md (this file)
- **Standards**:
  - .opencode/rules/artifact-formats.md
  - .opencode/rules/status-markers.md
  - .opencode/rules/artifact-management.md
  - .opencode/rules/tasks.md
- **Type**: markdown

## Overview

Task 540 implemented the core automatic agent registration infrastructure: 14 extensions have `opencode-agents.json` fragments, manifests declare `merge_targets.opencode_json`, and the extension loader correctly merges/unmerges agent definitions into `opencode.json`. Task 541 designed the remaining gaps. Task 542 closes four implementation gaps and updates the base template.

**Scope**: Wire automatic cleanup triggers, implement conflict detection for duplicate agent names, add fragment-to-manifest consistency verification, and make sync respect the `.managed` sidecar for `opencode.json`. Also update the base template to include missing core agents.

**Constraints**: All changes are additive or fix wiring; no breaking changes to existing merge/unmerge logic. Cleanup and conflict detection must remain non-blocking (warn, don't fail). Verification additions must not break existing extensions.

**Definition of done**: All four gaps are closed, TODO(541) annotations are removed, and the base template includes all 7 core agents.

## Research Integration

Integrated research report: `specs/542_implement_opencode_json_agent_registration/reports/01_opencode-json-agent-registration-research.md` (Task 542 research, produced 2026-05-07). Covers load/unload cycle architecture, current code locations, existing agent registration patterns, and detailed implementation recommendations for each gap.

## Goals & Non-Goals

- **Goals**:
  - Call `cleanup_stale_opencode_agents()` automatically on startup, after extension load, and after extension unload
  - Detect and warn when two extensions define the same agent name
  - Verify that `manifest.provides.agents` matches the extension's `opencode-agents.json` fragment during post-load verification
  - Respect the `.opencode.json.managed` sidecar in sync operations so unmanaged files are never overwritten
  - Update `.opencode/templates/opencode.json` to include `reviser` and `spawn` agents

- **Non-Goals**:
  - Changing the merge/unmerge algorithm or tracking format
  - Implementing runtime enforcement of the agent-name registry document
  - Adding new merge target types beyond `opencode_json`
  - Modifying how `{file:...}` references are resolved at CLI startup

## Risks & Mitigations

- **Risk**: Cleanup on startup adds measurable init latency. **Mitigation**: Cleanup reads a single small JSON file and only writes when stale entries are found; operation is typically sub-millisecond.
- **Risk**: Conflict detection warns on false positives (e.g., user manually added agent with same name as extension agent). **Mitigation**: Detection only fires when an extension tries to merge an agent whose key already exists in `opencode.json` and is tracked in `extensions.json` as owned by a different loaded extension. User-added agents without tracking metadata are ignored.
- **Risk**: New verification check breaks existing working extensions. **Mitigation**: Treat fragment-to-manifest mismatches as warnings (contribute to `verification.status = "warnings"` but do not downgrade to `failed`).
- **Risk**: Managed sidecar sync change prevents legitimate template updates. **Mitigation**: Managed files can still be replaced during `sync-all`; unmanaged files were already skipped, so behavior only changes for managed files (now eligible for replace).

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Wire Cleanup to Automatic Triggers [COMPLETED]
- **Goal:** Ensure `cleanup_stale_opencode_agents()` runs automatically after every event that could leave stale `{file:...}` references in `opencode.json`.
- **Tasks:**
  - [ ] **Task 1.1**: In `lua/neotex/plugins/ai/opencode.lua`, import the extension manager in `config()` and call `manager.cleanup_stale_opencode_agents()` after the server setup block (after line 59). Wrap in `pcall` to avoid breaking plugin init on error.
  - [ ] **Task 1.2**: In `lua/neotex/plugins/ai/shared/extensions/init.lua` `manager.load()`, call `manager.cleanup_stale_opencode_agents(project_dir)` after successful load (after line 548, replacing the TODO(541) comment).
  - [ ] **Task 1.3**: In `lua/neotex/plugins/ai/shared/extensions/init.lua` `manager.unload()`, call `manager.cleanup_stale_opencode_agents(project_dir)` after successful unload (after line 675, replacing the TODO(541) comment).
  - [ ] **Task 1.4**: Remove the TODO(541) comments at lines 545-546 and 672-673 in `init.lua`.
- **Timing:** 30 minutes
- **Depends on:** none

### Phase 2: Implement Conflict Detection in merge_opencode_agents [COMPLETED]
- **Goal:** Detect duplicate agent names across loaded extensions and emit a warning instead of silently skipping.
- **Tasks:**
  - [ ] **Task 2.1**: Add `extension_name` parameter to `M.merge_opencode_agents(target_path, fragment, project_dir, extension_name)` in `lua/neotex/plugins/ai/shared/extensions/merge.lua`. Update the call site in `init.lua` `process_merge_targets()` (line 131) to pass `ext_manifest.name or "unknown"`.
  - [ ] **Task 2.2**: In `merge_opencode_agents()`, before the silent skip at line 737, implement conflict detection:
    - Read `extensions.json` via `state_mod.read(project_dir, config)`
    - Get loaded extensions via `state_mod.list_loaded(state)`
    - For each loaded extension, get `merged_sections.opencode_json` via `state_mod.get_merged_sections(state, ext_name)`
    - If `merged_sections.opencode_json.keys` contains the conflicting `key`, emit a `vim.notify` warning: `Extension 'X' agent 'Y' conflicts with already-loaded extension 'Z'. Skipped.`
    - If no owner is found in state (e.g., user-added agent), silently skip without warning
  - [ ] **Task 2.3**: Remove the TODO(541) comment at lines 738-742 in `merge.lua`.
  - [ ] **Task 2.4**: Update the call site in `sync.lua` `reinject_loaded_extensions()` (line 282) to pass `ext_manifest.name or "unknown"` as the fourth argument.
- **Timing:** 45 minutes
- **Depends on:** 1

### Phase 3: Add verify_opencode_json_merge to verify.lua [COMPLETED]
- **Goal:** During post-load verification, confirm that `manifest.provides.agents` and the extension's `opencode-agents.json` fragment agree on agent names.
- **Tasks:**
  - [ ] **Task 3.1**: Add `verify_opencode_json_merge(extension_dir, ext_manifest)` helper function in `lua/neotex/plugins/ai/shared/extensions/verify.lua`:
    - Read `opencode-agents.json` from `extension_dir`
    - Extract agent names from fragment (handle both `{agent = {...}}` and bare `{...}` formats)
    - Extract agent names from `ext_manifest.provides.agents` by stripping `-agent.md` suffixes
    - Compute symmetric difference (agents in manifest but not fragment, and agents in fragment but not manifest)
    - Return `{passed = true}` if no mismatches, otherwise `{passed = false, missing_from_fragment = {...}, missing_from_manifest = {...}}`
  - [ ] **Task 3.2**: In `M.verify_extension()`, call `verify_opencode_json_merge()` after the existing index merge check (after line 392). Add `verification.opencode_json` field. If mismatches exist, append descriptive errors to `verification.errors` and set `verification.opencode_json.passed = false`.
  - [ ] **Task 3.3**: Ensure mismatches do NOT change `verification.status` to `failed`; they should only downgrade to `warnings` (the existing logic at line 395-397 already handles this if we append to `errors` without setting a critical failure flag).
  - [ ] **Task 3.4**: Remove the TODO(541) comment at lines 285-289 in `verify.lua`.
- **Timing:** 45 minutes
- **Depends on:** 1

### Phase 4: Respect Managed Sidecar in Sync [COMPLETED]
- **Goal:** Prevent sync from overwriting an unmanaged `opencode.json`; allow replacement of managed `opencode.json` during `sync-all`.
- **Tasks:**
  - [ ] **Task 4.1**: In `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` `collect_sync_artifacts()` (around line 897), update the `opencode.json` action determination:
    - If local file does not exist: action = "copy"
    - If local file exists and `local_path .. ".managed"` is readable: action = "replace"
    - If local file exists and no `.managed` sidecar: action = "skip"
  - [ ] **Task 4.2**: In `sync_files()` (around line 340), add a defensive guard: if `file.name == "opencode.json"` and the local file exists but has no `.managed` sidecar, force action to "skip" regardless of what `collect_sync_artifacts` decided.
  - [ ] **Task 4.3**: Remove the TODO(541) comment at lines 340-343 in `sync.lua`.
  - [ ] **Task 4.4**: Update the NOTE(541) at line 876-878 if it no longer applies, or rephrase it to describe the post-sync re-injection behavior without referencing the design spec decision number.
- **Timing:** 30 minutes
- **Depends on:** 1

### Phase 5: Update Base Template [COMPLETED]
- **Goal:** Ensure the base `opencode.json` template contains all 7 core agents defined in the `core` extension.
- **Tasks:**
  - [ ] **Task 5.1**: In `.opencode/templates/opencode.json`, add `reviser` agent definition matching the core extension fragment:
    - `description`: "Revise implementation plans based on feedback and new findings"
    - `mode`: "subagent"
    - `prompt`: "{file:.opencode/agent/subagents/reviser-agent.md}"
    - `tools`: `write`, `edit`, `bash`, `read`, `grep`, `glob`
  - [ ] **Task 5.2**: In `.opencode/templates/opencode.json`, add `spawn` agent definition matching the core extension fragment:
    - `description`: "Spawn sub-tasks to research blockers and overcome obstacles"
    - `mode`: "subagent"
    - `prompt`: "{file:.opencode/agent/subagents/spawn-agent.md}"
    - `tools`: `read`, `write`, `edit`, `bash`, `grep`, `glob`, `webfetch`, `websearch`
  - [ ] **Task 5.3**: Validate the updated template JSON is well-formed and consistent with `core/opencode-agents.json`.
- **Timing:** 15 minutes
- **Depends on:** 2, 3, 4

## Testing & Validation

- [ ] **Test 1**: Load an extension with agents (e.g., `core`). Verify `opencode.json` contains all expected agents. Verify no stale cleanup warning appears. Unload the extension. Verify agents are removed. Verify cleanup warning does not appear.
- [ ] **Test 2**: Manually corrupt `opencode.json` by adding an agent with `{file:nonexistent.md}`. Restart Neovim. Verify cleanup runs on startup and removes the stale agent with a notification.
- [ ] **Test 3**: Load two extensions that define the same agent name (simulate by temporarily duplicating an agent entry in a second extension's fragment). Verify a conflict warning notification is emitted and the second extension's agent is skipped.
- [ ] **Test 4**: Temporarily remove an agent from an extension's `opencode-agents.json` while keeping it in `manifest.provides.agents`. Load the extension. Verify post-load verification reports a warning (not failure) about the mismatch.
- [ ] **Test 5**: Create an unmanaged `opencode.json` (no `.managed` sidecar). Run `:OpencodeCommands` -> sync. Verify `opencode.json` is skipped. Add `.managed` sidecar. Run sync-all. Verify `opencode.json` is replaced.
- [ ] **Test 6**: Verify the updated `.opencode/templates/opencode.json` JSON is valid (`python3 -m json.tool .opencode/templates/opencode.json` or `jq . .opencode/templates/opencode.json`).

## Artifacts & Outputs

- `specs/542_implement_opencode_json_agent_registration/plans/01_opencode-json-agent-registration-plan.md` (this file)
- `specs/542_implement_opencode_json_agent_registration/summaries/01_opencode-json-agent-registration-summary.md` (expected after implementation)
- Modified files:
  - `lua/neotex/plugins/ai/opencode.lua`
  - `lua/neotex/plugins/ai/shared/extensions/init.lua`
  - `lua/neotex/plugins/ai/shared/extensions/merge.lua`
  - `lua/neotex/plugins/ai/shared/extensions/verify.lua`
  - `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
  - `.opencode/templates/opencode.json`

## Rollback/Contingency

- If cleanup triggers cause performance issues or unexpected side effects, revert the three `cleanup_stale_opencode_agents()` call additions in `opencode.lua` and `init.lua`. The function itself remains harmless since it is not called.
- If conflict detection causes excessive warnings, adjust the detection logic to only warn when both conflicting extensions are from the same config system (`.opencode` vs `.claude`), or silence warnings for specific known overlaps.
- If verification mismatches break CI or automated loading, change the verification result from contributing to `warnings` to a separate non-blocking `info` field.
- If managed sidecar sync behavior surprises users, restore the original unconditional "skip if exists" logic for `opencode.json`.
