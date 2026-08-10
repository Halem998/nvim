# Research Report: Design of opencode.json Agent Registration Mechanism

- **Task**: 541 - design_opencode_json_agent_registration
- **Started**: 2026-05-07T00:00:00Z
- **Completed**: 2026-05-07T01:15:00Z
- **Effort**: 1-2 hours
- **Dependencies**: 540 (completed - research on opencode.json schema, CLI validation, and extension agent registration gaps)
- **Sources/Inputs**:
  - `specs/540_research_opencode_json_and_extension_gaps/reports/01_opencode-json-research.md`
  - `specs/540_research_opencode_json_and_extension_gaps/plans/01_opencode-json-plan.md`
  - `specs/540_research_opencode_json_and_extension_gaps/summaries/01_opencode-json-summary.md`
  - `lua/neotex/plugins/ai/shared/extensions/merge.lua` (merge/unmerge strategies)
  - `lua/neotex/plugins/ai/shared/extensions/init.lua` (extension manager, cleanup)
  - `lua/neotex/plugins/ai/shared/extensions/loader.lua` (file copy engine)
  - `lua/neotex/plugins/ai/shared/extensions/verify.lua` (post-load verification)
  - `lua/neotex/plugins/ai/shared/extensions/manifest.lua` (manifest parsing/validation)
  - `lua/neotex/plugins/ai/shared/extensions/state.lua` (state tracking)
  - `lua/neotex/plugins/ai/shared/extensions/config.lua` (system configuration)
  - `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (sync operation)
  - `lua/neotex/plugins/ai/opencode/core/init.lua` (base template installer)
  - `lua/neotex/plugins/ai/shared/picker/config.lua` (picker configuration)
  - `.opencode/extensions/core/manifest.json` (reference manifest with opencode_json)
  - `.opencode/extensions/core/opencode-agents.json` (reference agent fragment)
  - `.opencode/extensions/present/manifest.json` (reference manifest with opencode_json)
  - `.opencode/extensions/present/opencode-agents.json` (reference agent fragment)
  - `.opencode/templates/opencode.json` (base template)
- **Artifacts**: `specs/541_design_opencode_json_agent_registration/reports/01_opencode-json-agent-registration-design.md`
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Project Context

- **Upstream Dependencies**: OpenCode CLI (`opencode` binary), extension manifest schema, `.opencode/templates/opencode.json`, `merge.lua` merge strategies, `manifest.lua` validation
- **Downstream Dependents**: All agent-providing extensions (15 extensions), project-level `opencode.json` files, sync operation, startup cleanup
- **Alternative Paths**: Manual editing of `opencode.json` (deprecated), computed-artifact approach (like `CLAUDE.md`) - deferred
- **Potential Extensions**: CI validation for fragment/manifest sync, agent name registry, automated fragment generation from agent `.md` frontmatter

## Executive Summary

- **The agent registration mechanism has been partially implemented by Task 540** but several DESIGN decisions remain unresolved regarding conflict resolution, validation scope, and lifecycle management.
- **Conflict resolution is the largest design gap**: When two extensions define the same agent name, the first-loaded wins silently, and unloading the winner orphans the second extension's expectation. No warning is issued, and the state becomes inconsistent.
- **The managed/unmanaged distinction** (via `.opencode.json.managed` sidecar) is a sound design pattern that should be extended to govern sync behavior and user customization boundaries.
- **Validation currently covers `{file:...}` reference existence** but does not verify fragment-to-manifest consistency, cross-extension agent name uniqueness, or tool assignment correctness.
- **Startup cleanup exists** (`cleanup_stale_opencode_agents`) but is not automatically triggered on Neovim startup, leaving a window where stale references can crash the OpenCode CLI.
- **Sync strategy needs refinement**: The interaction between base-template installation, merge-only semantics, and re-injection of loaded extensions creates ordering dependencies that can produce transient invalid states.

## Context & Scope

This research designs the complete opencode.json agent registration mechanism for the OpenCode extension system. Task 540 implemented the core infrastructure (fragments, manifests, merge/unmerge, validation, sync integration, cleanup). This report focuses on DESIGN decisions for:

1. Manifest schema requirements for agent registration
2. Merge/unmerge semantics and state tracking
3. Validation pipeline (pre-merge, post-merge, manifest validation)
4. Agent definition format standardization
5. Conflict resolution strategy
6. Sync and base-template lifecycle

The scope covers the OpenCode-specific extension system (`.opencode/`), not the Claude system (`.claude/`).

## Findings

### Finding 1: Manifest Schema Already Supports opencode_json Registration

The extension manifest schema (`manifest.lua` lines 91-113) validates `merge_targets` generically:

- Each merge target must have `source` and `target` fields
- `opencode_json` is not treated specially - it passes the same generic validation
- Task 540 added `opencode_json` targets to all 15 agent-providing extension manifests

The standard declaration pattern (from `core/manifest.json` lines 153-157):
```json
"opencode_json": {
  "source": "opencode-agents.json",
  "target": "opencode.json"
}
```

**Design status**: Complete. No schema changes needed.

### Finding 2: Merge/Unmerge Uses Key-Based Tracking with No-Overwrite Semantics

`merge.lua` lines 699-778 implement the merge/unmerge pair:

**Merge (`merge_opencode_agents`)**:
- Validates `{file:...}` references exist before merging (`validate_opencode_fragment`, line 668)
- Reads target `opencode.json`, creates `agent` section if missing
- Only adds keys that don't already exist (`target.agent[key] == nil`, line 733)
- Tracks added keys in `{keys = {...}}` for unmerge
- Returns `false, {error = ...}` on validation failure

**Unmerge (`unmerge_opencode_agents`)**:
- Reads target `opencode.json`
- Removes only tracked keys from `target.agent`
- Non-tracked keys (user additions, other extensions) are preserved

**State tracking** (`state.lua` lines 122-133, 189-198):
- `merged_sections.opencode_json` is stored in `extensions.json`
- Contains `{keys = {"agent1", "agent2", ...}}`
- Persisted across Neovim sessions

**Design status**: Functional but has edge cases (see Finding 5).

### Finding 3: Validation Pipeline Has Three Gaps

**Existing validation**:
1. **Pre-merge file reference validation** (`merge.lua` line 668): Checks `{file:...}` paths exist relative to project root. Run during `process_merge_targets` (`init.lua` line 131).
2. **Manifest structural validation** (`manifest.lua` line 119): Validates required fields, provides categories, merge_targets structure.
3. **Post-load verification** (`verify.lua` line 284): Checks agents/skills/rules/context files exist on disk, index entries merged, section injected.

**Validation gaps**:
1. **No fragment-to-manifest consistency check**: `verify.lua` does not verify that the agents declared in `opencode-agents.json` match `manifest.provides.agents`. A manifest could list 7 agents but the fragment could define 5 (or 9).
2. **No cross-extension agent name conflict detection**: Two extensions can define the same agent name. The first-loaded wins silently; the second is skipped. No error or warning is issued.
3. **No tool assignment validation**: Agent fragments assign tools heuristically (research agents get web tools, implementation agents get write/edit/bash). There's no validation that tool assignments are appropriate or complete.

**Design status**: Needs extension.

### Finding 4: Agent Definition Format Is Standardized but Informally

The `opencode-agents.json` fragment format (from `core/opencode-agents.json` and `present/opencode-agents.json`):

```json
{
  "agent": {
    "agent-name": {
      "description": "Human-readable description",
      "mode": "subagent",
      "prompt": "{file:.opencode/agent/subagents/name-agent.md}",
      "tools": {
        "read": true, "write": true, "edit": true,
        "glob": true, "grep": true, "bash": true,
        "webfetch": true, "websearch": true
      }
    }
  }
}
```

**Format rules established by Task 540**:
- Agent name = filename without `-agent.md` suffix
- Description = extracted from agent frontmatter `description` field
- Mode = `"subagent"` for all extension agents
- Prompt = `{file:.opencode/agent/subagents/{agent-name}-agent.md}`
- Tools: determined by agent name suffix (research/implementation/router/others)

**Design status**: Complete for current needs, but no formal schema document exists.

### Finding 5: Conflict Resolution Strategy Is Undefined

**Current behavior when two extensions define the same agent name**:

Scenario: Extension A and Extension B both define agent `"grant"`.
1. Load Extension A: `"grant"` added to `opencode.json`, tracked in `extensions.json`
2. Load Extension B: `"grant"` already exists, so merge is skipped silently
3. Unload Extension A: `"grant"` removed from `opencode.json`
4. Extension B's agent is now missing, but B is still marked as loaded

**Problems**:
- Silent data loss for Extension B
- Inconsistent state: B is loaded but its agent is not registered
- No user notification of the conflict
- No recovery mechanism

**Potential design options**:
1. **Namespaced agents**: Prefix extension name (`present/grant`, `founder/grant`). Rejected - CLI may not support `/` in agent names.
2. **First-loaded wins with warning**: Keep current behavior but notify user of conflict on load.
3. **Hard conflict on load**: Refuse to load Extension B if it would conflict. Requires unload of A or user override.
4. **Lazy conflict resolution**: Allow both to load but track conflicts; on unload of winner, re-merge loser.
5. **Global agent name registry**: Maintain a registry of reserved agent names per extension; validate at manifest load time.

**Design status**: Needs decision. Option 2 (warning) is minimal; Option 4 (lazy resolution) is most correct but complex.

### Finding 6: Sync Strategy Has Ordering Dependencies

The sync operation (`sync.lua`) handles `opencode.json` as a root file:

1. **Base template installation** (`sync.lua` lines 872-907):
   - `opencode.json` is in `root_file_names` for `.opencode`
   - Uses "skip" action if file exists (merge-only semantics)
   - If file doesn't exist, copies from global template

2. **Re-injection** (`sync.lua` lines 274-284, 1139-1142):
   - After a full sync (not merge-only), re-injects loaded extensions' agents
   - Calls `merge_opencode_agents` for each loaded extension

3. **Base installer** (`opencode/core/init.lua` lines 65-126):
   - `install_base_opencode_json()` installs template and creates `.managed` sidecar
   - Backs up unmanaged files to `opencode.json.user-backup`
   - Called via `on_load_all` callback in picker config (`shared/picker/config.lua` lines 91-98)

**Ordering problem**:
- `on_load_all` runs after sync completes
- If sync did a full replace (user chose "Sync all"), `opencode.json` is overwritten with base template
- Then re-injection runs, adding back extension agents
- Then `install_base_opencode_json` runs, but file already exists so it may skip

**However**, there's a subtle issue: if sync overwrites `opencode.json` with the base template BEFORE re-injection, there's a transient state where `opencode.json` lacks extension agents. If the user (or another process) reads `opencode.json` during this window, it sees an incomplete config.

**Design status**: Functional but has a transient-state window. The `.managed` sidecar is a good pattern that should be used more consistently.

### Finding 7: Startup Cleanup Exists but Is Not Triggered Automatically

`init.lua` lines 834-877 implement `cleanup_stale_opencode_agents()`:

- Scans `opencode.json` for `{file:...}` references
- Removes entries where the referenced file is missing
- Writes updated `opencode.json` via `merge_mod.write_json()`
- Notifies user of removed agents

**Current trigger**: None. The function exists on the manager but is not called during:
- Neovim startup
- Extension picker open
- Extension load/unload
- opencode.nvim plugin initialization

**Design gap**: The cleanup should run automatically at a well-defined point to prevent CLI crashes. Potential triggers:
1. On Neovim startup (in `opencode.lua` `config()` function)
2. Before each `opencode --port` invocation
3. After each extension load/unload
4. On `OpencodeExtensions` picker open

**Design status**: Needs trigger assignment.

### Finding 8: The Managed/Unmanaged Distinction Should Govern More Behaviors

`opencode/core/init.lua` lines 50-140 introduce the `.managed` sidecar pattern:

- `is_managed()` checks for `.opencode.json.managed` file
- `install_base_opencode_json()` backs up unmanaged configs, overwrites managed ones
- `needs_base_install()` returns true if file doesn't exist or is unmanaged

**Current usage**:
- Base template installer uses it to decide whether to overwrite
- Sync uses merge-only semantics (independent of managed flag)

**Potential extensions of the managed pattern**:
1. **Sync behavior**: Only overwrite managed `opencode.json`; always preserve unmanaged
2. **Cleanup scope**: Only clean stale entries from managed files; warn but don't modify unmanaged
3. **Extension merge**: Reject merging into unmanaged `opencode.json` (or warn strongly)
4. **Visual indicator**: Show `[managed]` or `[user]` in picker/status

**Design status**: Pattern exists but policy is incomplete.

## Decisions

### Decision 1: Adopt "First-Loaded Wins with Conflict Warning" Strategy

For agent name conflicts across extensions:
- Keep current no-overwrite semantics (first-loaded wins)
- Add explicit conflict detection and user notification
- Do NOT implement lazy re-merge on unload (too complex for current needs)
- Document that agent names should be unique across the ecosystem

**Rationale**: No-overwrite is the safest default. Adding warnings makes the behavior transparent without breaking existing workflows.

### Decision 2: Extend Validation to Cover Fragment-to-Manifest Consistency

Add post-load verification step that checks:
- Every agent in `manifest.provides.agents` has a matching entry in the extension's `opencode-agents.json`
- Every agent in `opencode-agents.json` has a matching file in `manifest.provides.agents`
- Agent names in fragment match the expected naming convention

**Rationale**: Prevents silent mismatches where manifest claims to provide agents but the fragment doesn't register them (or vice versa).

### Decision 3: Trigger Startup Cleanup on Neovim Startup and After Each Load/Unload

- Run `cleanup_stale_opencode_agents()` in `opencode.lua` `config()` function during plugin initialization
- Also run it after each successful extension load/unload (in `init.lua` manager)
- This ensures `opencode.json` is always valid before the user opens the OpenCode terminal

**Rationale**: The cleanup is idempotent and fast. Running it automatically eliminates the stale-reference crash class entirely.

### Decision 4: Use Managed Flag to Govern Sync Overwrite Behavior

- Sync should check the `.managed` sidecar before overwriting `opencode.json`
- If unmanaged, sync should skip `opencode.json` entirely (or use merge-only)
- If managed, sync can overwrite with base template, then re-inject extensions
- Document that users who want manual control should remove the `.managed` file

**Rationale**: Respects user customizations while allowing automatic management for users who want it.

### Decision 5: Maintain Current Agent Definition Format (No Schema Changes)

The `opencode-agents.json` fragment format is adequate. No changes needed to the JSON schema.

**Rationale**: Task 540 already standardized the format. Changing it now would require re-generating all 15 fragments.

## Recommendations

### High Priority: Implement Conflict Detection in merge_opencode_agents

**Owner**: `merge.lua` / `init.lua`
**Action**: Before skipping an existing agent key, check if it was added by a different extension. If so, log a warning:

```
Warning: Extension 'present' agent 'grant' conflicts with already-loaded extension 'founder'.
Agent 'grant' was not registered. Unload 'founder' first, or rename the agent.
```

**Implementation approach**:
- Read `extensions.json` to find which extension owns each existing agent key
- Store agent-to-extension mapping in state (or compute on demand)
- In `merge_opencode_agents`, when `target.agent[key] ~= nil`, check if the key is in the mapping

### High Priority: Add Fragment-to-Manifest Consistency Verification

**Owner**: `verify.lua`
**Action**: Add `verify_opencode_json_merge()` function that:
1. Reads the extension's `opencode-agents.json`
2. Compares agent names against `manifest.provides.agents`
3. Reports mismatches as verification errors

**Integration**: Call from `verify_extension()` after existing checks.

### High Priority: Wire Startup Cleanup to Automatic Triggers

**Owner**: `opencode.lua` / `init.lua`
**Action**:
1. In `opencode.lua` `config()` function, after setting up server functions:
   ```lua
   local ext_manager = require("neotex.plugins.ai.opencode.extensions")
   ext_manager.cleanup_stale_opencode_agents()
   ```
2. In `init.lua` `manager.load()` and `manager.unload()`, after successful operations:
   ```lua
   manager.cleanup_stale_opencode_agents(project_dir)
   ```

### Medium Priority: Respect Managed Flag in Sync

**Owner**: `sync.lua`
**Action**: In `sync_files()` for `opencode.json`:
1. Check for `.opencode.json.managed` before deciding action
2. If unmanaged and file exists, change action from "skip" to "copy-with-backup" or simply skip
3. If managed, proceed with current behavior (skip if exists, or replace if sync-all)

### Medium Priority: Create Agent Name Registry Documentation

**Owner**: Documentation / `.opencode/context/`
**Action**: Create `.opencode/context/reference/agent-name-registry.md` documenting:
- Reserved agent names (core agents: build, plan, task-planner, etc.)
- Extension agent naming conventions (use descriptive, non-conflicting names)
- Process for proposing new agent names to avoid collisions

### Low Priority: Consider Computed Artifact for opencode.json

**Owner**: Architecture / future task
**Action**: Evaluate generating `opencode.json` from scratch on every load/unload (like `CLAUDE.md`). This would eliminate merge/unmerge complexity entirely.

**Pros**: No stale entries, no conflicts, deterministic
**Cons**: Loses manual customizations unless stored separately; larger architectural change

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Agent name conflicts cause silent data loss | Medium | High | Implement conflict detection with warnings (Decision 1) |
| Fragment/manifest mismatch goes undetected | Medium | Medium | Add consistency verification (Recommendation 2) |
| User customizations overwritten by sync | Medium | Medium | Respect managed flag (Recommendation 4) |
| Stale references crash CLI before cleanup runs | Low | High | Wire cleanup to startup trigger (Recommendation 3) |
| Two extensions loaded, one unloaded, orphaning shared agent name | Low | High | Document that agent names must be unique; conflict detection warns user |
| opencode-agents.json fragments drift from agent files | Medium | Low | CI check (future) or manual audit during extension updates |

## Context Extension Recommendations

- **Topic**: Extension manifest schema documentation
- **Gap**: No documented reference for `merge_targets.opencode_json` field exists in `.opencode/context/`
- **Recommendation**: Add `.opencode/context/reference/extension-manifest-schema.md` documenting all `merge_targets` keys with examples

- **Topic**: Agent registration design patterns
- **Gap**: The merge/unmerge tracking pattern for JSON files is not documented as a reusable design
- **Recommendation**: Document the key-based tracking pattern in `.opencode/context/patterns/json-merge-tracking.md` for future use with other JSON merge targets

- **Topic**: opencode.json lifecycle management
- **Gap**: No documentation explains the managed/unmanaged distinction, sync behavior, or cleanup strategy
- **Recommendation**: Create `.opencode/context/reference/opencode-json-lifecycle.md` documenting the full lifecycle from template installation through extension registration to cleanup

## Appendix

### A.1 Merge/Unmerge Code Paths

```
manager.load()
  -> process_merge_targets()
    -> line 123: if config.merge_target_key == "opencode_md" and ext_manifest.merge_targets.opencode_json
      -> line 131: merge_mod.merge_opencode_agents(target_path, fragment, project_dir)
        -> merge.lua line 706: validate_opencode_fragment()
        -> merge.lua line 733: add keys, track in {keys = {...}}
        -> merge.lua line 745: return tracked
      -> merged_sections.opencode_json = tracked
  -> state_mod.mark_loaded() -> stores merged_sections in extensions.json

manager.unload()
  -> reverse_merge_targets()
    -> line 181: if merged_sections.opencode_json ...
      -> line 184: merge_mod.unmerge_opencode_agents(target_path, tracked)
        -> merge.lua line 768: remove tracked keys from target.agent
```

### A.2 Sync Code Path for opencode.json

```
M.load_all_globally()
  -> M.scan_all_artifacts()
    -> lines 873-907: root_file_names includes "opencode.json"
    -> action = "skip" if exists, "copy" if missing
  -> execute_sync()
    -> sync_files() with merge_only flag
      -> line 340: skip if action == "skip"
  -> reinject_loaded_extensions() (if not merge_only)
    -> line 275-284: re-merge opencode_json for each loaded extension
  -> on_load_all callback (if configured)
    -> core.install_base_opencode_json() (only if picker config has on_load_all)
```

### A.3 Managed Sidecar File Format

```
opencode.json              # The actual config file
opencode.json.managed      # Sidecar marker file (content: "managed-by: neotex-extensions\n")
opencode.json.user-backup  # Backup of previous unmanaged config
```

The sidecar is checked by `is_managed()` in `opencode/core/init.lua` line 54.

### A.4 Agent Fragment Generation Rules (from Task 540)

| Rule | Value |
|------|-------|
| Agent name | Filename without `-agent.md` suffix |
| Description | Extracted from agent frontmatter `description` field |
| Mode | `"subagent"` for all extension agents |
| Prompt | `{file:.opencode/agent/subagents/{agent-name}-agent.md}` |
| Tools (research) | read, write, edit, glob, grep, bash, webfetch, websearch |
| Tools (implementation) | write, edit, bash, read, glob, grep |
| Tools (router) | read, grep, glob |
| Tools (other) | full toolset |

### A.5 References

- `lua/neotex/plugins/ai/shared/extensions/merge.lua` lines 662-778
- `lua/neotex/plugins/ai/shared/extensions/init.lua` lines 122-186, 834-877
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` lines 284-400
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` lines 91-113
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` lines 274-284, 869-907
- `lua/neotex/plugins/ai/opencode/core/init.lua` lines 50-140
- `lua/neotex/plugins/ai/shared/picker/config.lua` lines 78-100
