# Implementation Plan: Convert opencode.json to Computed-Artifact Pattern

- **Task**: 543 - convert_opencode_json_to_computed_artifact
- **Status**: [COMPLETED]
- **Effort**: 8 hours
- **Dependencies**: Task #542
- **Research Inputs**: specs/543_convert_opencode_json_to_computed_artifact/reports/01_computed-artifact-pattern.md
- **Artifacts**: specs/543_convert_opencode_json_to_computed_artifact/plans/01_convert-opencode-json-computed-artifact.md, specs/543_convert_opencode_json_to_computed_artifact/summaries/01_convert-opencode-json-summary.md
- **Standards**:
  - .opencode/rules/artifact-formats.md
  - .opencode/rules/state-management.md
  - .opencode/rules/status-markers.md
  - .opencode/rules/tasks.md
- **Type**: markdown

## Overview

Replace the merge-target approach for `opencode.json` with a computed-artifact regeneration pipeline, mirroring the existing `generate_claudemd()` pattern in `merge.lua`. The current per-extension merge/unmerge logic is complex, suffers from an agent-orphaning edge case, and requires stale-agent cleanup. The computed-artifact pattern rebuilds `opencode.json` from scratch on every load/unload cycle by aggregating agent fragments from all loaded extensions over a base template. The existing `.opencode.json.managed` sidecar gates whether regeneration runs.

The computed-artifact approach enables centralized permission configuration in the base template: auto-approval for in-root edits (`permission.edit: "allow"`), ask-for-approval for external directory access (`permission.external_directory: { "*": "ask" }`), and deny rules for destructive bash commands. This eliminates permission prompt fatigue for workspace-internal operations while maintaining safety boundaries, all without requiring per-extension permission fragments.

This plan covers the core function implementation, pipeline refactoring across six source modules, base template permission configuration, manifest updates for all 16 extensions, and reusable pattern documentation.

## Research Integration

Integrated report: `specs/543_convert_opencode_json_to_computed_artifact/reports/01_computed-artifact-pattern.md` (plan_version 1).

## Goals & Non-Goals

- **Goals**:
  - Implement `generate_opencode_json()` in `merge.lua` that rebuilds `opencode.json` from base template + extension fragments
  - Integrate managed/unmanaged sidecar gating into the generation pipeline
  - Integrate `{file:...}` reference validation into the generation loop
  - Configure the base template with `permission.edit: "allow"` and `permission.external_directory: { "*": "ask" }`
  - Include bash command safety deny rules (`rm -rf *`, `sudo *`, `chmod 777 *`, `chmod -R *`) in the base template
  - Guide agents to use `specs/tmp/` instead of `/tmp/` for temporary work via base template agent instructions
  - Refactor `init.lua` to call `generate_opencode_json()` after load and unload instead of per-extension merge/unmerge
  - Update `sync.lua` to use a single generation call instead of per-extension re-injection
  - Update `verify.lua` to validate fragment-to-manifest consistency without relying on tracked merged state
  - Update `install_base_opencode_json()` to trigger generation immediately after template installation
  - Remove or deprecate `merge_opencode_agents()` and `unmerge_opencode_agents()`
  - Remove `merge_targets.opencode_json` from all 16 extension manifests
  - Document the computed-artifact pattern in `.opencode/context/patterns/computed-artifacts.md`
  - Update `.opencode/context/reference/opencode-json-lifecycle.md` and `.opencode/context/patterns/json-merge-tracking.md`

- **Non-Goals**:
  - Changing the managed/unmanaged sidecar semantics or marker file format
  - Applying the computed-artifact pattern to `settings.json` or `index.json` in this task
  - Adding new agents or renaming existing agents
  - Modifying the `generate_claudemd()` function
  - Converting `opencode.json` to a non-JSON format
  - Migrating `tts-notify.sh` temp paths from `/tmp/` to `specs/tmp/` (covered by task 548)
  - Updating `general-research-agent.md` to reference `specs/tmp/` (covered by task 548)
  - Documenting the dual-system architecture (Claude Code vs OpenCode permissions, covered by task 548)

## Risks & Mitigations

- **Risk**: User customizations in a managed `opencode.json` are lost on the first regeneration after upgrade.
  - **Mitigation**: Managed files are explicitly machine-owned. A pre-regeneration scan can detect agents not present in the base template or any loaded extension fragment and emit a one-time warning. Users can remove the `.opencode.json.managed` sidecar to preserve their file.

- **Risk**: Generation failure leaves `opencode.json` in a bad state.
  - **Mitigation**: Validate the computed table with `pcall(vim.json.encode)` before writing. Write to a temporary file and atomically rename to the target path.

- **Risk**: Unmanaged files no longer receive automatic extension agents.
  - **Mitigation**: This is intentional behavior change. Users who want automatic agents must use managed mode. The extension picker and documentation must communicate this clearly.

- **Risk**: Backward incompatibility during partial implementation.
  - **Mitigation**: Phase ordering ensures all callers of the new function are updated before old functions are removed. Extension manifest updates happen after the code no longer reads `merge_targets.opencode_json`.

- **Risk**: Core fragment and base template have overlapping agent keys (e.g., `planner` vs `task-planner`).
  - **Mitigation**: First-wins conflict resolution preserves base template agents exactly as the current merge behavior does. Only agents not already in the base template are added from fragments.

- **Risk**: Permission block in the base template conflicts with user customizations or extension expectations.
  - **Mitigation**: The permission block is part of the base template and uses first-wins semantics; extension fragments merge only into the `agent` table, never into `permission`. Users who need custom permissions can switch to unmanaged mode.

- **Risk**: Agents continue using `/tmp/` despite base template guidance to use `specs/tmp/`.
  - **Mitigation**: Include the temp directory guidance in the primary/default agent instructions so it is visible on every session. Verify during end-to-end testing that generated `opencode.json` contains the guidance.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5 | 1 |
| 3 | 6, 7 | 2, 3, 4, 5 |
| 4 | 8 | 6, 7 |
| 5 | 9 | 8 |

Phases within the same wave can execute in parallel.

### Phase 1: Implement generate_opencode_json() in merge.lua [COMPLETED]

- **Goal:** Create the core computed-artifact generation function following the `generate_claudemd()` fragment-collection pattern, and update the base template with permission configuration.

- **Tasks:**
  - [x] **Task 1.1**: Add `M.generate_opencode_json(project_dir, config)` to `lua/neotex/plugins/ai/shared/extensions/merge.lua`.
    - Read base template from `.opencode/templates/opencode.json`.
    - Read `extensions.json` state and build ordered loaded extension list: core first, remaining extensions in stable sorted order.
    - For each loaded extension, check for `opencode-agents.json` at `extension.path .. "/opencode-agents.json"` (convention-based discovery).
    - Read each fragment and validate `{file:...}` references using existing `validate_opencode_fragment()`.
    - Deep-merge fragment `agent` tables into the base template's `agent` table with first-wins semantics (skip keys that already exist). **Do not merge fragments into the `permission` table.**
    - On validation failure for a fragment, emit a warning and skip that fragment (do not abort generation).
  - [x] **Task 1.2**: Add managed/unmanaged gating.
    - Check for `.opencode.json.managed` sidecar marker.
    - If managed: proceed to write.
    - If unmanaged: skip writing entirely and return success.
  - [x] **Task 1.3**: Add safe atomic write.
    - Validate final computed table with `pcall(vim.json.encode)` before writing.
    - Write to a temporary file and rename atomically to `opencode.json`.
    - Return boolean success and string|nil error.
  - [x] **Task 1.4**: Add a backward-compat wrapper or stub for `merge_opencode_agents()` and `unmerge_opencode_agents()` so existing callers do not break during transition (to be removed in Phase 6).
  - [x] **Task 1.5**: Update `.opencode/templates/opencode.json` base template to include a `permission` block.
    - Add `permission.edit: "allow"` for auto-approved in-root writes.
    - Add `permission.external_directory` with `"*": "ask"` as the default (ask for approval for all external directories).
    - Add `permission.bash` with `"*": "allow"` default and explicit deny rules for: `rm -rf *`, `sudo *`, `chmod 777 *`, `chmod -R *`.
  - [x] **Task 1.6**: Update base template agent instructions to guide agents to use `specs/tmp/` instead of `/tmp/` for temporary work. Update the primary/default agent instructions to include this guidance.

- **Timing:** 2 hours
- **Depends on:** none
- **Completed:** 2026-05-07T18:55:00Z

### Phase 2: Refactor init.lua load/unload pipeline [COMPLETED]

- **Goal:** Replace per-extension merge/unmerge with single regeneration calls and remove obsolete tracking.

- **Tasks:**
  - [x] **Task 2.1**: Remove `opencode_json` handling block from `process_merge_targets()` (lines 122-146). Leave a comment noting that `opencode.json` is now a computed artifact regenerated after state update.
  - [x] **Task 2.2**: Remove `opencode_json` handling block from `reverse_merge_targets()` (lines 180-186). Leave a comment analogous to the existing CLAUDE.md comment.
  - [x] **Task 2.3**: Add `generate_opencode_json()` call immediately after `generate_claudemd()` in `manager.load()` (after line 532). Wrap in non-fatal error handling with `vim.schedule` notification.
  - [x] **Task 2.4**: Add `generate_opencode_json()` call immediately after `generate_claudemd()` in `manager.unload()` (after line 669). Wrap in non-fatal error handling.
  - [x] **Task 2.5**: Remove `manager.cleanup_stale_opencode_agents()` function entirely (lines 846-893). Stale agents are inherently cleaned by regeneration.
  - [x] **Task 2.6**: Remove the `cleanup_stale_opencode_agents` invocation from `manager.load()` (lines 545-551) and `manager.unload()` (lines 676-682).
  - [x] **Task 2.7**: Verify that `state_mod.mark_loaded()` no longer receives `merged_sections.opencode_json` data. Ensure `merged_sections` from `process_merge_targets` does not contain an `opencode_json` key.

- **Timing:** 1 hour
- **Depends on:** 1
- **Completed:** 2026-05-07T19:00:00Z

### Phase 3: Update sync.lua sync-all flow [COMPLETED]

- **Goal:** Replace the per-extension re-injection loop with a single generation call.

- **Tasks:**
  - [x] **Task 3.1**: In `reinject_loaded_extensions()`, remove the `opencode_json` re-injection block (lines 274-284). Replace with a single call to `merge_mod.generate_opencode_json(project_dir, config)` at the end of the function, after all other re-injections.
  - [x] **Task 3.2**: Update the comment at lines 878-880 to mention that `generate_opencode_json()` also restores extension agents atomically after sync overwrites.
  - [x] **Task 3.3**: Verify that `scan_all_artifacts()` opencode.json logic remains correct: managed files get "replace" action (overwritten with base template), then `reinject_loaded_extensions` calls `generate_opencode_json()` to add extension agents in the same synchronous Lua call.

- **Timing:** 1 hour
- **Depends on:** 1
- **Completed:** 2026-05-07T19:05:00Z

### Phase 4: Update verify.lua validation [COMPLETED]

- **Goal:** Adapt verification to the computed-artifact pattern.

- **Tasks:**
  - [x] **Task 4.1**: Update `verify_opencode_json_merge()` to continue verifying fragment-to-manifest consistency (agents declared in `manifest.provides.agents` must match agents in the extension's `opencode-agents.json` fragment). This logic does not depend on tracked merged state and should be preserved.
  - [x] **Task 4.2**: Remove or simplify any verification logic that checks whether agents were "injected into the target file" (no longer applicable because the file is regenerated, not injected).
  - [x] **Task 4.3**: Verify that `M.verify_extension()` still calls `verify_opencode_json_merge()` and surfaces mismatches as non-critical warnings.

- **Timing:** 0.5 hours
- **Depends on:** 1
- **Completed:** 2026-05-07T19:08:00Z

### Phase 5: Update opencode core installer [COMPLETED]

- **Goal:** Ensure newly installed managed files immediately reflect loaded extensions and contain the permission block.

- **Tasks:**
  - [x] **Task 5.1**: Update `install_base_opencode_json()` in `lua/neotex/plugins/ai/opencode/core/init.lua` to call `generate_opencode_json(project_dir, config)` after writing the managed marker and template. Pass the config from `config_mod.opencode(project_dir)`.
  - [x] **Task 5.2**: Handle the case where generation fails: log a non-fatal warning but do not fail the installation.
  - [x] **Task 5.3**: Verify `needs_base_install()` behavior is unchanged.
  - [x] **Task 5.4**: Verify that the base template written by the installer contains the `permission` block with `edit: "allow"`, `external_directory: { "*": "ask" }`, and bash deny rules. The installer should write the same `.opencode/templates/opencode.json` updated in Task 1.5.

- **Timing:** 0.5 hours
- **Depends on:** 1

### Phase 6: Remove deprecated merge/unmerge functions [COMPLETED]

- **Goal:** Clean up obsolete code after all callers have been migrated.

- **Tasks:**
  - [x] **Task 6.1**: Remove `M.merge_opencode_agents()` from `merge.lua` (lines 700-784).
  - [x] **Task 6.2**: Remove `M.unmerge_opencode_agents()` from `merge.lua` (lines 786-816).
  - [x] **Task 6.3**: Retain `M.validate_opencode_fragment()` because it is still used by `generate_opencode_json()`.
  - [x] **Task 6.4**: Search the entire codebase for any remaining references to `merge_opencode_agents` or `unmerge_opencode_agents` and resolve them.

- **Timing:** 0.5 hours
- **Depends on:** 2, 3, 4, 5
- **Completed:** 2026-05-07T19:12:00Z

### Phase 7: Update extension manifests [COMPLETED]

- **Goal:** Remove obsolete merge target declarations from all 16 extensions.

- **Tasks:**
  - [x] **Task 7.1**: Remove the `opencode_json` entry from `merge_targets` in each of the following manifests:
    - `.opencode/extensions/core/manifest.json`
    - `.opencode/extensions/epidemiology/manifest.json`
    - `.opencode/extensions/filetypes/manifest.json`
    - `.opencode/extensions/formal/manifest.json`
    - `.opencode/extensions/founder/manifest.json`
    - `.opencode/extensions/latex/manifest.json`
    - `.opencode/extensions/lean/manifest.json`
    - `.opencode/extensions/memory/manifest.json`
    - `.opencode/extensions/nix/manifest.json`
    - `.opencode/extensions/nvim/manifest.json`
    - `.opencode/extensions/present/manifest.json`
    - `.opencode/extensions/python/manifest.json`
    - `.opencode/extensions/slidev/manifest.json`
    - `.opencode/extensions/typst/manifest.json`
    - `.opencode/extensions/web/manifest.json`
    - `.opencode/extensions/z3/manifest.json`
  - [x] **Task 7.2**: Verify that `provides.agents` in each manifest still accurately reflects the agents in the extension's `opencode-agents.json` fragment (or absence thereof). Do not modify `provides.agents` unless there is a pre-existing mismatch.
  - [x] **Task 7.3**: Ensure manifest JSON remains valid after edits (no trailing commas).

- **Timing:** 1 hour
- **Depends on:** 2, 3, 4, 5
- **Completed:** 2026-05-07T19:18:00Z

### Phase 8: Document computed-artifact pattern [COMPLETED]

- **Goal:** Create reusable pattern documentation and update existing references.

- **Tasks:**
  - [x] **Task 8.1**: Write `.opencode/context/patterns/computed-artifacts.md` with the following sections:
    - Overview: definition and when to use versus merge-target
    - Invariants: determinism, no per-extension tracking, managed sidecar gating, implicit removal
    - Pattern template: read base template, order extensions, collect fragments, merge/assemble, validate, write if managed
    - Checklist for applying the pattern to new files
    - Examples: `CLAUDE.md` (via `generate_claudemd`) and `opencode.json` (via `generate_opencode_json`)
  - [x] **Task 8.2**: Update `.opencode/context/reference/opencode-json-lifecycle.md`:
    - Remove Stage 2 (per-extension merge), Stage 4 (stale cleanup), and Stage 5 (per-extension unmerge)
    - Add a single "Regeneration" stage after load/unload and sync
    - Update state diagram
    - Update managed/unmanaged semantics: unmanaged files skip regeneration entirely (no longer receive extension agents)
  - [x] **Task 8.3**: Update `.opencode/context/patterns/json-merge-tracking.md`:
    - Add a note at the top stating that `opencode.json` is no longer managed via JSON merge tracking
    - Retain the pattern documentation for other targets such as `settings.json`
    - Update the "Reusability" section to reference the computed-artifact pattern as the preferred approach for files that can be fully regenerated
  - [x] **Task 8.4**: In the computed-artifacts pattern documentation, include a subsection on "Centralized Permission Configuration" that explains how the base template can declare permissions (edit, external_directory, bash rules) and agent instructions (e.g., temp directory guidance) that apply uniformly across all generated artifacts.

- **Timing:** 1 hour
- **Depends on:** 6, 7
- **Completed:** 2026-05-07T19:25:00Z

### Phase 9: End-to-end testing and verification [COMPLETED]

- **Goal:** Validate the full pipeline under realistic conditions, including permission configuration correctness.

- **Tasks:**
  - [x] **Task 9.1**: Test managed mode:
    - Start with no `opencode.json` in a test project.
    - Trigger base installation and verify `generate_opencode_json()` runs immediately.
    - Load the `core` extension and verify base template + core fragment agents are present.
    - Load a second extension (e.g., `nvim`) and verify its agents appear without duplicating core agents.
    - Unload the second extension and verify its agents disappear while core agents remain.
    - Unload `core` and verify only base template agents remain.
  - [x] **Task 9.2**: Test unmanaged mode:
    - Remove `.opencode.json.managed` sidecar.
    - Load an extension and verify `opencode.json` is NOT modified.
  - [x] **Task 9.3**: Test sync-all:
    - Run sync-all with a managed `opencode.json` and verify the file is replaced with base template then regenerated with loaded extension agents.
  - [x] **Task 9.4**: Test orphaning fix:
    - Load two extensions that define the same agent key (simulate or use test data).
    - Unload the first-loaded extension and verify the agent key is still present because the second extension's fragment still contributes it.
  - [x] **Task 9.5**: Test validation:
    - Introduce a broken `{file:...}` reference in a test fragment and verify generation emits a warning and skips the fragment.
  - [x] **Task 9.6**: Run `:TestFile` or `:TestSuite` if tests exist for the extension system.
  - [x] **Task 9.7**: Verify permission block in generated `opencode.json`:
    - Confirm `permission.edit` is `"allow"`.
    - Confirm `permission.external_directory["*"]` is `"ask"`.
    - Confirm `permission.bash` contains deny rules for `rm -rf *`, `sudo *`, `chmod 777 *`, and `chmod -R *`.
    - Confirm extension fragments did not override or remove the permission block.
  - [x] **Task 9.8**: Verify temp directory guidance:
    - Confirm generated `opencode.json` contains agent instructions referencing `specs/tmp/` instead of `/tmp/`.
    - Confirm the guidance is present in the primary/default agent instructions.

- **Timing:** 1.5 hours
- **Depends on:** 8
- **Completed:** 2026-05-07T19:30:00Z

## Testing & Validation

- [x] `generate_opencode_json()` produces deterministic output given the same set of loaded extensions and base template.
- [x] Managed files are regenerated after every extension load and unload.
- [x] Unmanaged files are never modified by `generate_opencode_json()`.
- [x] The orphaning edge case is resolved: unloading one extension does not remove agents still provided by another loaded extension.
- [x] `reinject_loaded_extensions()` after sync-all restores all loaded extension agents in a single call.
- [x] `verify_opencode_json_merge()` still detects manifest/fragment mismatches.
- [x] All 16 extension manifests are valid JSON and no longer contain `merge_targets.opencode_json`.
- [x] No remaining references to `merge_opencode_agents` or `unmerge_opencode_agents` in the codebase.
- [x] Documentation accurately reflects the new lifecycle.
- [x] Generated `opencode.json` contains `permission.edit: "allow"` and `permission.external_directory: { "*": "ask" }`.
- [x] Generated `opencode.json` contains bash deny rules for destructive commands.
- [x] Generated `opencode.json` agent instructions reference `specs/tmp/` for temporary work.
- [x] Extension fragments cannot override the base template `permission` block.

## Artifacts & Outputs

- `specs/543_convert_opencode_json_to_computed_artifact/plans/01_convert-opencode-json-computed-artifact.md` (this file)
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` (add `generate_opencode_json`, remove deprecated functions)
- `lua/neotex/plugins/ai/shared/extensions/init.lua` (remove merge/unmerge/cleanup, add regeneration calls)
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (update reinjection)
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` (update validation logic)
- `lua/neotex/plugins/ai/opencode/core/init.lua` (update installer to trigger generation)
- `.opencode/templates/opencode.json` (updated with permission block and temp directory guidance)
- `.opencode/extensions/*/manifest.json` (16 manifests updated)
- `.opencode/context/patterns/computed-artifacts.md` (new pattern documentation)
- `.opencode/context/reference/opencode-json-lifecycle.md` (updated lifecycle reference)
- `.opencode/context/patterns/json-merge-tracking.md` (updated with deprecation note)

## Rollback/Contingency

- If critical regressions are discovered during testing, revert all source file changes with `git checkout -- <paths>` and restore the 16 manifests from git history.
- If the computed-artifact approach proves incompatible with a specific extension's fragment structure, the old `merge_opencode_agents()` code can be restored from git history and the plan pivoted to a hybrid approach.
- To preserve user data during rollback: before any deployment, advise users with managed `opencode.json` containing custom agents to remove the `.managed` sidecar or back up their file.
- If permission configuration causes unexpected prompt behavior, the base template can be reverted to remove the `permission` block while keeping the computed-artifact pattern intact.
