# Research Report: opencode.json Schema and Extension Agent Registration Gaps

- **Task**: 540 - research_opencode_json_and_extension_gaps
- **Started**: 2026-05-07T00:00:00Z
- **Completed**: 2026-05-07T00:30:00Z
- **Effort**: 2 hours
- **Dependencies**: None
- **Sources/Inputs**:
  - `lua/neotex/plugins/ai/opencode.lua` (plugin config)
  - `lua/neotex/plugins/ai/shared/extensions/init.lua` (extension loader)
  - `lua/neotex/plugins/ai/shared/extensions/merge.lua` (merge strategies)
  - `lua/neotex/plugins/ai/shared/extensions/loader.lua` (file copy engine)
  - `lua/neotex/plugins/ai/shared/extensions/state.lua` (state tracking)
  - `lua/neotex/plugins/ai/shared/extensions/config.lua` (config presets)
  - `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (sync operation)
  - `.opencode/templates/opencode.json` (base template)
  - `.opencode/extensions/*/manifest.json` (17 extension manifests)
  - `.opencode/extensions/present/opencode-agents.json` (only existing agents fragment)
  - `/home/benjamin/Projects/Logos/Vision/opencode.json` (crashed project config)
- **Artifacts**: `specs/540_research_opencode_json_and_extension_gaps/reports/01_opencode-json-research.md`
- **Standards**: report-format.md, subagent-return.md

## Project Context

- **Upstream Dependencies**: OpenCode CLI (`opencode` binary), extension manifest schema, `.opencode/templates/opencode.json`
- **Downstream Dependents**: All 17 extensions that provide agents, project-level `opencode.json` files
- **Alternative Paths**: Manual editing of `opencode.json` (current broken practice)
- **Potential Extensions**: Computed-artifact approach for `opencode.json` (like `CLAUDE.md`), pre-merge validation pipeline

## Executive Summary

- **`opencode.json` is the OpenCode CLI configuration file** at project root defining available agents with `mode`, `prompt`, `description`, and `tools`. The `prompt` field supports `{file:...}` placeholders resolved at CLI startup.
- **Merge/unmerge code for `opencode.json` exists but is completely unreachable**: `merge.lua` has `merge_opencode_agents()` and `unmerge_opencode_agents()`, but ZERO of the 17 extension manifests declare `merge_targets.opencode_json`, so the code path in `init.lua` (line 123) is never exercised.
- **The crash root cause is stale `{file:...}` references**: When extensions are unloaded, their `.md` agent files are deleted from `.opencode/agent/subagents/`, but `opencode.json` entries remain because no unmerge runs. The OpenCode CLI validates `{file:...}` paths at startup and crashes when files are missing.
- **Only the `present` extension ships an `opencode-agents.json` fragment**, but its `manifest.json` does not reference it under `merge_targets`.
- **The base template at `.opencode/templates/opencode.json`** contains 7 core agents; it is never synced to project root by the sync operation, leaving projects without a valid starting `opencode.json` unless one is created manually.

## Context & Scope

This research investigates:
1. The `opencode.json` schema and how the OpenCode CLI validates it
2. How the Neovim extension loader currently handles `opencode.json`
3. Why manually-added agent entries cause startup crashes when extensions unload
4. Why the extension loader does not automatically register agents in `opencode.json`
5. What changes are needed to make agent registration automatic and safe

The scope covers the OpenCode-specific extension system (`.opencode/`), not the Claude system (`.claude/`).

## Findings

### Finding 1: opencode.json Schema and CLI Behavior

The `opencode.json` schema (from `.opencode/templates/opencode.json` and the crashed project config):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "default_agent": "build",
  "agent": {
    "build": { "mode": "primary" },
    "plan": { "mode": "primary", "prompt": "...", "tools": { "write": false } },
    "task-planner": {
      "mode": "subagent",
      "prompt": "{file:.opencode/agent/subagents/planner-agent.md}",
      "tools": { "write": true, "edit": true, "read": true }
    }
  }
}
```

Key observations:
- Top-level `agent` object maps agent names to configuration objects
- `prompt` can be inline text or a `{file:...}` placeholder
- The CLI resolves `{file:...}` at startup by reading the referenced file
- If the referenced file does not exist, the CLI crashes (this is the observed behavior)
- The base template includes 7 agents: `build`, `plan`, `task-planner`, `general-research`, `general-implementation`, `meta-builder`, `code-reviewer`
- Four of these use `{file:...}` prompts pointing to `.opencode/agent/subagents/*.md`

### Finding 2: Extension Loader Architecture

The extension loader (`init.lua`) handles three merge target types in `process_merge_targets()`:

1. **settings** -> `merge_settings()` -> merges JSON fragments (e.g., `settings-fragment.json`)
2. **index** -> `append_index_entries()` -> appends context index entries
3. **opencode_json** -> `merge_opencode_agents()` -> merges agent definitions into `opencode.json`

The `opencode_json` path is gated on line 123:
```lua
if config.merge_target_key == "opencode_md" and ext_manifest.merge_targets.opencode_json then
```

For the OpenCode system, `config.merge_target_key` is `"opencode_md"` (set in `config.lua` line 72), so the first condition is true. The second condition requires the manifest to declare `merge_targets.opencode_json`.

The corresponding unmerge in `reverse_merge_targets()` (line 172) has the same gate.

### Finding 3: Zero Extensions Declare opencode_json Merge Target

A grep across all 17 extension manifests for `opencode_json` returned **zero matches**. A grep for `opencode-agents` also returned **zero matches**.

Only one extension (`present`) even contains an `opencode-agents.json` file:
- `.opencode/extensions/present/opencode-agents.json` defines 5 agents: `grant`, `budget`, `timeline`, `funds`, `slides`
- Each uses `{file:.opencode/agent/subagents/{name}-agent.md}` prompts
- However, `present/manifest.json` does NOT reference this file in `merge_targets`

The crashed project (`/home/benjamin/Projects/Logos/Vision/opencode.json`) contains agents that match extension-provided agents:
- `spreadsheet`, `document`, `presentation`, `filetypes-router` -> from `filetypes` extension
- `typst-implementation`, `typst-research` -> from `typst` extension
- `grant` -> from `present` extension

These entries were added manually (or by an undocumented script), not by the extension loader.

### Finding 4: Agent Files Are Copied But Not Registered

When an extension is loaded, `loader.copy_simple_files()` copies `.md` files from the extension's `agents/` directory to the project's `.opencode/agent/subagents/` (per `agents_subdir = "agent/subagents"`). The files exist on disk after load.

However, because no `opencode_json` merge target is declared:
- `opencode.json` is never updated to include the new agents
- The OpenCode CLI does not know these agents exist
- The agents are effectively invisible to the CLI unless manually added

### Finding 5: Unload Deletes Files But Leaves opencode.json Stale

When an extension is unloaded:
1. `reverse_merge_targets()` runs, but skips `opencode_json` because the manifest doesn't declare it
2. `loader.remove_installed_files()` deletes the copied `.md` agent files from `.opencode/agent/subagents/`
3. If the user (or some other process) had previously added agent entries to `opencode.json`, those entries now reference deleted files
4. The OpenCode CLI crashes on next startup because `{file:...}` references point to missing files

### Finding 6: sync.lua Does Not Sync opencode.json

The sync operation (`sync.lua` line 869) defines root files for `.opencode` as:
```lua
root_file_names = { "AGENTS.md", "OPENCODE.md", "settings.json", ".gitignore", "README.md", "QUICK-START.md" }
```

`opencode.json` is **not included**. This means:
- Projects don't receive the base template automatically
- Even if a project has a manually-created `opencode.json`, sync won't update it
- The base template at `.opencode/templates/opencode.json` is orphaned

### Finding 7: The Base Template Has Partial File References

The base template includes agents with `{file:...}` prompts:
- `task-planner` -> `.opencode/agent/subagents/planner-agent.md`
- `general-research` -> `.opencode/agent/subagents/general-research-agent.md`
- `general-implementation` -> `.opencode/agent/subagents/general-implementation-agent.md`
- `meta-builder` -> `.opencode/agent/subagents/meta-builder-agent.md`

These files are provided by the `core` extension (listed in `core/manifest.json` `provides.agents`). When core is loaded, these files are copied to the correct location, making the template valid. When core is NOT loaded, the template would be invalid.

## Decisions

- **Decision 1**: The `opencode_json` merge target mechanism is the correct design; the problem is that no extension manifests use it.
- **Decision 2**: Manual editing of `opencode.json` is the root cause of the crash class; the fix is to make registration automatic so manual edits are unnecessary.
- **Decision 3**: The base template should be treated similarly to other root files (synced to project root), OR `opencode.json` should become a computed artifact like `CLAUDE.md`.
- **Decision 4**: Pre-merge validation of `{file:...}` references is essential to prevent a malformed extension manifest from corrupting the project's `opencode.json`.

## Recommendations

### High Priority: Add opencode_json Merge Targets to All Extension Manifests

**Owner**: Extension maintainers / automated script
**Action**: For every extension that provides agents, add to `manifest.json`:

```json
"merge_targets": {
  "opencode_md": { ... },
  "index": { ... },
  "opencode_json": {
    "source": "opencode-agents.json",
    "target": "opencode.json"
  }
}
```

And create an `opencode-agents.json` file in the extension root with agent definitions matching the agents in `provides.agents`.

### High Priority: Add opencode.json Validation Before Merge

**Owner**: `merge.lua` / extension loader
**Action**: In `merge_opencode_agents()`, before writing to `opencode.json`, validate that all `{file:...}` references in the fragment exist at their resolved paths (relative to project root). If validation fails, abort the merge and return an error.

**Implementation sketch**:
```lua
local function validate_opencode_fragment(fragment, project_dir)
  local agents = fragment.agent or fragment
  for name, config in pairs(agents) do
    if config.prompt and config.prompt:match("^%{file:") then
      local path = config.prompt:match("^%{file:(.+)%}")
      local full_path = project_dir .. "/" .. path
      if vim.fn.filereadable(full_path) ~= 1 then
        return false, "Missing file for agent '" .. name .. "': " .. path
      end
    end
  end
  return true, nil
end
```

**Note**: The validation must account for the fact that agent files are copied BEFORE merge targets are processed (in `init.lua` lines 395-494), so by the time `process_merge_targets` runs, the files should already exist.

### Medium Priority: Treat opencode.json as a Root File During Sync

**Owner**: `sync.lua`
**Action**: Add `"opencode.json"` to the `root_file_names` list for `.opencode` (line 869). This ensures new projects receive the base template. Use merge-only semantics (don't overwrite existing `opencode.json` if it already has extension agents).

### Medium Priority: Startup Cleanup of Broken References

**Owner**: Extension loader or opencode.nvim plugin
**Action**: On Neovim startup (or when the extension picker opens), scan the project's `opencode.json` for `{file:...}` references that point to missing files. Remove stale entries and notify the user. This acts as defense-in-depth against corruption from manual edits or failed unloads.

### Low Priority: Consider Computed Artifact Approach

**Owner**: Architecture / future task
**Action**: Evaluate whether `opencode.json` should become a fully computed artifact (like `CLAUDE.md`), generated from:
1. Base template (core agents)
2. Extension fragments (loaded extensions' `opencode-agents.json`)

**Pros**:
- Fully deterministic; no stale entries possible
- No merge/unmerge complexity
- Always consistent with loaded extensions

**Cons**:
- Loses manual customizations (user-added agents would be erased)
- Requires storing custom agents elsewhere (e.g., a separate `opencode.custom.json`)
- Larger architectural change

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Adding `opencode_json` to manifests without validation causes corrupted `opencode.json` | Medium | High | Implement pre-merge validation of `{file:...}` references before writing |
| Existing projects with manually-edited `opencode.json` lose custom agents when unmerge runs | High | Medium | Startup cleanup pass removes stale entries; warn users that manual edits should move to a custom config |
| `opencode-agents.json` fragments get out of sync with `provides.agents` | High | Low | Add CI check that verifies every agent in `provides.agents` has a corresponding entry in `opencode-agents.json` |
| Core extension unload removes base agents, breaking template references | Low | High | Block unloading of `core` when dependents are loaded (already implemented in `init.lua` line 582) |
| Sync overwrites project's `opencode.json` and removes extension agents | Medium | Medium | Use merge-only for `opencode.json` during sync; re-inject loaded extensions after sync (sync.lua already re-injects merge targets) |

## Context Extension Recommendations

- **Topic**: Extension manifest schema documentation
- **Gap**: No documented reference for the `merge_targets.opencode_json` field exists in `.opencode/context/` or extension docs
- **Recommendation**: Add a schema reference document under `.opencode/context/reference/extension-manifest-schema.md` documenting all `merge_targets` keys (`claudemd`/`opencode_md`, `index`, `settings`, `opencode_json`) with examples

- **Topic**: `opencode.json` computed artifact pattern
- **Gap**: The `generate_claudemd()` pattern for computed artifacts is not documented as a reusable pattern for other files
- **Recommendation**: Document the computed artifact pattern in `.opencode/context/patterns/computed-artifacts.md` for future use with `opencode.json`, `settings.json`, or other merge-target files

## Appendix

### A.1 Extension Manifests with Agent Provides

The following extensions provide agents but do NOT declare `merge_targets.opencode_json`:

| Extension | Agents Provided |
|-----------|----------------|
| core | 7 agents (general-research, general-implementation, planner, meta-builder, code-reviewer, reviser, spawn) |
| filetypes | 5 agents (filetypes-router, document, spreadsheet, presentation, deck) |
| founder | 16 agents (analyze, legal-analysis, strategy, financial-analysis, finance, deck-research, legal-council, founder-spreadsheet, market, meeting, founder-plan, project, deck-builder, deck-planner, founder-implement) |
| formal | 4 agents (formal-research, physics-research, math-research, logic-research) |
| latex | 2 agents (latex-research, latex-implementation) |
| lean | 2 agents (lean-research, lean-implementation) |
| memory | 0 agents (provides skills only) |
| nix | 2 agents (nix-research, nix-implementation) |
| nvim | 2 agents (neovim-research, neovim-implementation) |
| present | 9 agents (grant, budget, timeline, funds, slides-research, pptx-assembly, slidev-assembly, slide-planner, slide-critic) |
| python | 2 agents (python-research, python-implementation) |
| slidev | 0 agents (provides skills only) |
| typst | 2 agents (typst-research, typst-implementation) |
| web | 2 agents (web-research, web-implementation) |
| z3 | 2 agents (z3-research, z3-implementation) |
| epidemiology | 2 agents (epidemiology-research, epidemiology-implementation) |

### A.2 Merge Code Path Analysis

The `opencode_json` merge code path in `init.lua`:

```
manager.load()
  -> process_merge_targets()
    -> line 123: if config.merge_target_key == "opencode_md" and ext_manifest.merge_targets.opencode_json
      -> line 129: read_json(source_path)
      -> line 131: merge_mod.merge_opencode_agents(target_path, fragment)
        -> merge.lua line 669: M.merge_opencode_agents()
          -> reads/writes opencode.json
          -> tracks added keys in {keys = {...}}
          -> stores in merged_sections.opencode_json
  -> state_mod.mark_loaded()
    -> stores merged_sections in extensions.json

manager.unload()
  -> reverse_merge_targets()
    -> line 172: if config.merge_target_key == "opencode_md" and merged_sections.opencode_json ...
      -> line 175: merge_mod.unmerge_opencode_agents(target_path, tracked)
        -> merge.lua line 712: M.unmerge_opencode_agents()
          -> reads opencode.json
          -> removes tracked keys from target.agent
          -> writes updated opencode.json
```

### A.3 Crashed Project opencode.json Analysis

The crashed project config (`/home/benjamin/Projects/Logos/Vision/opencode.json`) contains these extension-specific agents:

- `spreadsheet` -> `{file:.opencode/agent/subagents/spreadsheet-agent.md}` -> from `filetypes` extension
- `document` -> `{file:.opencode/agent/subagents/document-agent.md}` -> from `filetypes` extension
- `presentation` -> `{file:.opencode/agent/subagents/presentation-agent.md}` -> from `filetypes` extension
- `filetypes-router` -> `{file:.opencode/agent/subagents/filetypes-router-agent.md}` -> from `filetypes` extension
- `typst-implementation` -> `{file:.opencode/agent/subagents/typst-implementation-agent.md}` -> from `typst` extension
- `typst-research` -> `{file:.opencode/agent/subagents/typst-research-agent.md}` -> from `typst` extension
- `grant` -> `{file:.opencode/agent/subagents/grant-agent.md}` -> from `present` extension

When any of these extensions is unloaded, the `.md` files are deleted but `opencode.json` retains the entries, causing the CLI startup crash.

### A.4 References

- `lua/neotex/plugins/ai/shared/extensions/init.lua` lines 122-136, 171-176
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` lines 662-737
- `lua/neotex/plugins/ai/shared/extensions/config.lua` lines 64-75
- `.opencode/extensions/present/opencode-agents.json`
- `.opencode/templates/opencode.json`
- `/home/benjamin/Projects/Logos/Vision/opencode.json`
