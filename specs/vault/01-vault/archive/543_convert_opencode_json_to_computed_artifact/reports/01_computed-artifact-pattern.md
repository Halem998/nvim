# Research Report: Convert opencode.json to Computed-Artifact Pattern

- **Task**: 543 - convert_opencode_json_to_computed_artifact
- **Started**: 2026-05-07T20:00:00Z
- **Completed**: 2026-05-07T21:30:00Z
- **Effort**: 1.5 hours
- **Dependencies**: 542
- **Sources/Inputs**:
  - `lua/neotex/plugins/ai/shared/extensions/merge.lua` (generate_claudemd, merge_opencode_agents, unmerge_opencode_agents)
  - `lua/neotex/plugins/ai/shared/extensions/init.lua` (process_merge_targets, reverse_merge_targets, load/unload hooks)
  - `lua/neotex/plugins/ai/shared/extensions/verify.lua` (verify_opencode_json_merge)
  - `lua/neotex/plugins/ai/shared/extensions/state.lua` (merged_sections tracking)
  - `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (reinject_loaded_extensions)
  - `lua/neotex/plugins/ai/shared/extensions/config.lua` (OpenCode config preset)
  - `.opencode/extensions/core/manifest.json` (merge_targets.opencode_json declaration)
  - `.opencode/templates/opencode.json` (base template)
  - `.opencode/extensions/core/opencode-agents.json` (core fragment example)
  - `.opencode/context/reference/opencode-json-lifecycle.md` (managed/unmanaged sidecar semantics)
  - `.opencode/context/patterns/json-merge-tracking.md` (current merge tracking pattern)
- **Artifacts**:
  - `specs/543_convert_opencode_json_to_computed_artifact/reports/01_computed-artifact-pattern.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Project Context

- **Upstream Dependencies**: `merge.lua` (generate_claudemd), `config.lua` (OpenCode preset), `state.lua` (loaded extension list), extension manifests (`merge_targets.opencode_json`)
- **Downstream Dependents**: `init.lua` (load/unload pipeline), `sync.lua` (sync-all reinjection), `verify.lua` (post-load verification), `.opencode/context/reference/opencode-json-lifecycle.md`
- **Alternative Paths**: Keep current merge/unmerge tracking (rejected due to orphaning bug and complexity)
- **Potential Extensions**: Apply computed-artifact pattern to `settings.json` or other JSON merge targets; generalize into a reusable `generate_computed_json()` helper

## Executive Summary

- The current opencode.json management uses per-extension merge/unmerge with key tracking in `extensions.json`. This is complex, suffers from an orphaning edge case, and requires a separate stale-agent cleanup pass.
- `CLAUDE.md` already uses a computed-artifact pattern (`generate_claudemd()`) that rebuilds the file from scratch after every load/unload cycle. It needs no tracking and produces deterministic output.
- A `generate_opencode_json()` function can aggregate agent entries from all loaded extensions' `opencode-agents.json` fragments over a base template, using the same ordering and fragment-collection logic as `generate_claudemd()`.
- The existing managed/unmanaged sidecar pattern (`.opencode.json.managed`) gates whether the computed artifact is written: managed files are fully regenerated; unmanaged files are preserved untouched.
- Migration removes approximately 120 lines of merge/unmerge logic, eliminates the orphaning bug, and aligns the opencode.json lifecycle with CLAUDE.md.
- Six to eight source files require modification, plus new pattern documentation.

## Context & Scope

This research evaluates replacing the merge-target approach for `opencode.json` with a computed-artifact regeneration pipeline. The scope includes:

1. Analyzing the current per-extension merge/unmerge lifecycle.
2. Deep-diving into `generate_claudemd()` as the reference computed-artifact implementation.
3. Designing `generate_opencode_json()` with managed/unmanaged sidecar awareness.
4. Identifying every file that must change and assessing migration risks.
5. Drafting the structure for `.opencode/context/patterns/computed-artifacts.md` as a reusable pattern.

## Findings

### Current Merge-Target Approach

The merge-target approach is implemented across several modules:

- `merge.lua:700-784` (`merge_opencode_agents`): Reads an extension's `opencode-agents.json` fragment and adds missing keys to the target `opencode.json`. Returns a `keys` array for tracking.
- `merge.lua:786-816` (`unmerge_opencode_agents`): Removes the tracked keys on unload.
- `init.lua:72-186` (`process_merge_targets` / `reverse_merge_targets`): Orchestrates per-extension merge during load and reverse merge during unload.
- `init.lua:846-893` (`cleanup_stale_opencode_agents`): Post-load/unload pass that scans `{file:...}` references and removes agents whose referenced files no longer exist.
- `sync.lua:220-287` (`reinject_loaded_extensions`): After a full sync-all replace, re-runs `merge_opencode_agents` for every loaded extension to restore agents.
- `state.lua:122-133` (`mark_loaded`): Persists `merged_sections.opencode_json` (the tracked `keys` array) into `extensions.json`.

**Orphaning edge case**: When two extensions define the same agent key, the first loaded extension wins and the second's key is skipped. When the first extension is unloaded, its tracked key is removed, even though the second extension is still loaded and expected to provide that agent. The agent remains missing until the second extension is reloaded. This is documented in `.opencode/context/reference/opencode-json-lifecycle.md`.

### CLAUDE.md Computed-Artifact Pattern

`generate_claudemd()` (`merge.lua:537-660`) rebuilds `CLAUDE.md` from scratch after every load/unload cycle:

1. Reads `extensions.json` to get the list of loaded extensions.
2. Orders them: core first, then remaining extensions in stable sorted order.
3. For each loaded extension, reads the manifest's `merge_targets.claudemd.source` fragment path.
4. Reads the header template from core's `templates/claudemd-header.md`.
5. Concatenates header + fragments with double-newline separators.
6. Writes the result to the target path.

No tracking data is stored in `extensions.json` for CLAUDE.md. Removal of an extension's content is implicit: the extension is no longer in the loaded list, so its fragment is excluded from the next generation. This pattern is already integrated into `init.lua`, where `generate_claudemd()` is called unconditionally after successful load (`init.lua:527`) and after successful unload (`init.lua:664`).

### Design for generate_opencode_json()

The proposed function follows the same fragment-collection pipeline as `generate_claudemd()`, adapted for JSON structure:

**Data sources**:
- Base template: `.opencode/templates/opencode.json` (provides `$schema`, `default_agent`, and core agents).
- Extension fragments: each loaded extension's `opencode-agents.json`, located via `manifest.merge_targets.opencode_json.source`.
- Existing `opencode.json` (read only to determine whether the file is managed or unmanaged).

**Ordering & merging**:
- Same as `generate_claudemd`: core first, then remaining loaded extensions in stable sorted order.
- Fragments are deep-merged into the base template's `agent` table.
- Conflict resolution: first-wins (no override). This preserves core agents and matches the current merge semantics where `target.agent[key] == nil` is the condition for insertion.

**Managed/unmanaged sidecar**:
- Check for `.opencode.json.managed` marker file.
- **Managed**: write the computed artifact directly to `opencode.json`. The file is fully deterministic given the set of loaded extensions and the base template.
- **Unmanaged**: skip writing. The existing `opencode.json` is preserved exactly as-is. This is the "unmanaged layer" where user customizations live.

**Stale reference handling**:
- Because the artifact is regenerated from current fragments, agents from unloaded extensions are automatically excluded.
- Broken `{file:...}` references from still-loaded extensions can still occur if the user deletes agent files manually. Validation should be integrated into the generation loop: if a fragment references a missing file, emit a warning and skip that agent (or the whole fragment), rather than writing invalid data.

**Proposed signature**:
```lua
function M.generate_opencode_json(project_dir, config)
  -- returns boolean success, string|nil error
end
```

### Files Requiring Modification

1. **`lua/neotex/plugins/ai/shared/extensions/merge.lua`**
   - Add `generate_opencode_json()`.
   - Remove or deprecate `merge_opencode_agents()` and `unmerge_opencode_agents()`.
   - Retain `validate_opencode_fragment()` for reference validation during generation.

2. **`lua/neotex/plugins/ai/shared/extensions/init.lua`**
   - Remove `opencode_json` handling from `process_merge_targets()` and `reverse_merge_targets()`.
   - Call `generate_opencode_json()` after successful load and after successful unload (adjacent to the existing `generate_claudemd()` calls).
   - Remove or repurpose `cleanup_stale_opencode_agents()`; stale agents are inherently cleaned by regeneration.
   - Update state tracking so that `merged_sections.opencode_json` is no longer written.

3. **`lua/neotex/plugins/ai/shared/extensions/verify.lua`**
   - Update `verify_opencode_json_merge()` to verify that manifest `provides.agents` matches the extension's fragment, without relying on tracked merged state.
   - Remove or simplify the verification logic that checks whether agents were injected into the target file (no longer needed because the file is regenerated, not injected).

4. **`lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`**
   - In `reinject_loaded_extensions()`, replace the `merge_opencode_agents` loop with a single call to `generate_opencode_json()`.
   - Update the `opencode.json` sync action logic in `scan_all_artifacts()`: managed files are replaced with the base template, then generation adds extension agents atomically.

5. **`lua/neotex/plugins/ai/opencode/core/init.lua`**
   - Update `install_base_opencode_json()` to create the `.managed` sidecar and trigger `generate_opencode_json()` so that newly installed files immediately reflect loaded extensions.

6. **`.opencode/context/patterns/computed-artifacts.md`**
   - New documentation file describing the computed-artifact pattern, its invariants, and how to apply it to future merge targets.

7. **`.opencode/context/patterns/json-merge-tracking.md`**
   - Update to note that `opencode.json` is no longer managed via JSON merge tracking; retain the pattern documentation for other targets such as `settings.json`.

8. **`.opencode/context/reference/opencode-json-lifecycle.md`**
   - Rewrite lifecycle stages to remove per-extension merge/unmerge stages and describe the single regeneration step.

## Decisions

1. **Adopt full computed-artifact regeneration for managed opencode.json**, matching the CLAUDE.md pattern.
2. **Preserve unmanaged files by skipping regeneration entirely.** The `.opencode.json.managed` sidecar is the gate. Users who want automatic extension agents must use managed mode; users who want full control use unmanaged mode.
3. **Retain first-wins conflict resolution** to maintain parity with current merge semantics.
4. **Integrate `{file:...}` validation into generation** rather than running a separate cleanup pass after the fact.
5. **Do not preserve per-extension tracking in `extensions.json`** for opencode.json. The loaded extension list is the single source of truth.

## Recommendations

1. **Implement `generate_opencode_json()` in `merge.lua`** (owner: implementer).
   - Read base template, collect fragments from loaded extensions, merge `agent` tables, validate references, and write output.
2. **Refactor `init.lua` load/unload pipeline** (owner: implementer).
   - Remove `opencode_json` from `process_merge_targets` and `reverse_merge_targets`.
   - Add `generate_opencode_json(project_dir, config)` calls immediately after `generate_claudemd()` on load and unload.
3. **Update `sync.lua` reinjection** (owner: implementer).
   - Replace the per-extension `merge_opencode_agents` loop in `reinject_loaded_extensions` with a single generation call.
4. **Update lifecycle reference and patterns docs** (owner: implementer).
   - Write `.opencode/context/patterns/computed-artifacts.md`.
   - Update `.opencode/context/reference/opencode-json-lifecycle.md` and `.opencode/context/patterns/json-merge-tracking.md`.
5. **Add migration notice** (owner: implementer).
   - If an existing managed `opencode.json` contains user-added agents outside the base template, those agents will be lost on the first regeneration after upgrade. A one-time scan and warning is recommended.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| User customizations in managed `opencode.json` are lost on regeneration | Medium | Managed files are explicitly marked as machine-owned. Users can remove the `.managed` sidecar to preserve their file. A pre-regeneration scan for non-base agents can emit a warning. |
| Unmanaged files no longer receive automatic extension agents | Low | Intentional behavior change. Users who want automatic agents must use managed mode. The extension picker and documentation should communicate this. |
| Generation failure leaves `opencode.json` in a bad state | Low | Validate the computed table with `pcall(vim.json.encode)` before writing. Consider writing to a temporary file and atomically renaming. |
| Sync-all transient window where only base agents exist | Low | `generate_opencode_json()` runs immediately after sync file replacement, inside the same synchronous Lua call. The window is bounded and single-threaded, identical to today's behavior. |

## Context Extension Recommendations

- **Topic**: Computed-artifact pattern documentation
- **Gap**: No reusable pattern doc exists for the "regenerate from fragments" approach used by `generate_claudemd()` and soon `generate_opencode_json()`.
- **Recommendation**: Create `.opencode/context/patterns/computed-artifacts.md` with a generic template, invariants, and a checklist for applying the pattern to new files.

- **Topic**: opencode.json lifecycle reference
- **Gap**: The existing lifecycle doc describes the merge/unmerge stages.
- **Recommendation**: Update `.opencode/context/reference/opencode-json-lifecycle.md` to describe the single regeneration stage and revised managed/unmanaged semantics.

## Appendix

### References

- `generate_claudemd()`: `lua/neotex/plugins/ai/shared/extensions/merge.lua`, lines 537-660
- `merge_opencode_agents()`: `lua/neotex/plugins/ai/shared/extensions/merge.lua`, lines 700-784
- `unmerge_opencode_agents()`: `lua/neotex/plugins/ai/shared/extensions/merge.lua`, lines 786-816
- `process_merge_targets()`: `lua/neotex/plugins/ai/shared/extensions/init.lua`, lines 72-148
- `reverse_merge_targets()`: `lua/neotex/plugins/ai/shared/extensions/init.lua`, lines 150-186
- `cleanup_stale_opencode_agents()`: `lua/neotex/plugins/ai/shared/extensions/init.lua`, lines 846-893
- `reinject_loaded_extensions()`: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`, lines 220-287
- Managed/unmanaged sidecar semantics: `.opencode/context/reference/opencode-json-lifecycle.md`
- JSON merge tracking pattern: `.opencode/context/patterns/json-merge-tracking.md`
- Core manifest with `merge_targets.opencode_json`: `.opencode/extensions/core/manifest.json`, lines 153-156
- Base template: `.opencode/templates/opencode.json`
- Core agent fragment: `.opencode/extensions/core/opencode-agents.json`
