# OpenCode Agent Registration Design Specification

- **Task**: 541 - design_opencode_json_agent_registration
- **Status**: [COMPLETED]
- **Started**: 2026-05-07T00:00:00Z
- **Completed**: 2026-05-07T02:00:00Z
- **Effort**: 45 minutes
- **Dependencies**: 540 (completed)
- **Artifacts**: specs/541_design_opencode_json_agent_registration/designs/01_agent-registration-design-spec.md
- **Standards**: artifact-formats.md, status-markers.md

## Overview

This document formalizes the design decisions for the opencode.json agent registration mechanism in the OpenCode extension system. Task 540 implemented the core infrastructure (fragments, manifests, merge/unmerge, validation, sync integration, cleanup). This specification documents the remaining design gaps: conflict resolution strategy, validation pipeline extensions, sync lifecycle policies, and the managed/unmanaged distinction.

The definition of done is a set of actionable specifications that implementation agents can follow to close the identified gaps without introducing new design questions.

## Problem Scope

The OpenCode extension system enables third-party extensions to register agents in `opencode.json` via `merge_targets.opencode_json` declarations in their `manifest.json`. Task 540 built the infrastructure; however, five design decisions remain unresolved:

1. What happens when two extensions define the same agent name?
2. How do we ensure every agent declared in a manifest actually appears in the fragment?
3. When should stale agent references be cleaned up automatically?
4. How does the managed/unmanaged flag govern sync behavior?
5. Should the agent definition format change?

This document answers each question with concrete rules, examples, and file references.

---

## Decision 1: First-Loaded Wins with Conflict Warning

### Current Behavior

`merge.lua` line 733 implements no-overwrite semantics: if `target.agent[key]` already exists, the incoming agent is silently skipped.

### Conflict Scenario

Extension A and Extension B both define agent `"grant"`:

1. Load Extension A: `"grant"` added to `opencode.json`, tracked in `extensions.json`
2. Load Extension B: `"grant"` already exists, so merge is skipped silently
3. Unload Extension A: `"grant"` removed from `opencode.json`
4. Extension B's agent is now missing, but B is still marked as loaded

### Design Rule

- **Keep no-overwrite semantics** (first-loaded wins)
- **Add explicit conflict detection** before skipping an existing key
- **Notify the user** via `vim.notify` with `vim.log.levels.WARN`
- **Do NOT implement lazy re-merge on unload** (too complex for current needs; deferred to future task)

### Conflict Detection Algorithm

1. Before `merge_opencode_agents` skips a key (line 733), check if the key was added by a different extension
2. Read `extensions.json` from the project directory
3. Build an agent-to-extension mapping from `merged_sections.opencode_json.keys` entries
4. If the conflicting key belongs to another extension, emit a warning

### Warning Message Format

```
Extension 'present' agent 'grant' conflicts with already-loaded extension 'founder'.
Agent 'grant' was not registered. Unload 'founder' first, or rename the agent.
```

### Orphaning Edge Case

When Extension A (winner) is unloaded, Extension B's (loser) agent remains missing. Because lazy re-merge is deferred, the user must:
- Unload and reload Extension B to re-register its agent, OR
- Rename one of the agents before loading both extensions

This edge case is documented in `.opencode/context/reference/agent-name-registry.md` (see Phase 2) and in the warning message itself.

### Implementation Target

- File: `lua/neotex/plugins/ai/shared/extensions/merge.lua`
- Line: near line 733 (inside the `if target.agent[key] == nil then` block)
- Function: `merge_opencode_agents`

---

## Decision 2: Fragment-to-Manifest Consistency Validation

### Current Behavior

`verify.lua` line 284 (`verify_extension`) checks that agents listed in `manifest.provides.agents` exist as files on disk. It does NOT verify that the agents declared in `manifest.provides.agents` match the entries in the extension's `opencode-agents.json` fragment.

### Design Rule

Add a new verification function `verify_opencode_json_merge()` that checks:

1. **Manifest-to-Fragment completeness**: Every agent filename in `manifest.provides.agents` must have a matching entry in `opencode-agents.json`
2. **Fragment-to-Manifest completeness**: Every agent entry in `opencode-agents.json` must have a matching filename in `manifest.provides.agents`
3. **Naming convention compliance**: Agent names in the fragment must equal the filename without the `-agent.md` suffix

### Verification Rules

Given `manifest.provides.agents = ["grant-agent.md", "budget-agent.md"]` and `opencode-agents.json`:

```json
{
  "agent": {
    "grant": { ... },
    "budget": { ... }
  }
}
```

- Rule 1 passes: both manifest filenames have fragment entries
- Rule 2 passes: both fragment entries have manifest filenames
- Rule 3 passes: `"grant"` == `"grant-agent.md"` minus suffix; same for `"budget"`

### Failure Handling

- Report mismatches as verification errors in the `verification.errors` array
- Set `verification.opencode_json = { passed = false, mismatches = [...] }`
- Overall status becomes `"warnings"` (not `"failed"`, since the extension still loads)

### Implementation Target

- File: `lua/neotex/plugins/ai/shared/extensions/verify.lua`
- Line: near line 284 (after existing verification steps, before final status determination)
- Function: new `verify_opencode_json_merge()` called from `verify_extension()`

---

## Decision 3: Startup Cleanup Triggers

### Current Behavior

`cleanup_stale_opencode_agents()` exists in `init.lua` (lines 834-877) but is never called automatically. Stale `{file:...}` references can crash the OpenCode CLI if a user deletes an agent file or switches branches.

### Design Rule

Run `cleanup_stale_opencode_agents()` at three trigger points:

1. **Neovim startup**: In `opencode.lua` `config()` function, after setting up server functions
2. **Post-load**: After each successful `manager.load()` call
3. **Post-unload**: After each successful `manager.unload()` call

### Trigger Point Details

**Neovim startup** (`opencode.lua` `config()`):
```lua
local ext_manager = require("neotex.plugins.ai.opencode.extensions")
ext_manager.cleanup_stale_opencode_agents()
```

**Post-load** (`init.lua` `manager.load()`):
After `state_mod.mark_loaded(state)` and success notification, call:
```lua
manager.cleanup_stale_opencode_agents(project_dir)
```

**Post-unload** (`init.lua` `manager.unload()`):
After `state_mod.mark_unloaded(state, ext.name)` and success notification, call:
```lua
manager.cleanup_stale_opencode_agents(project_dir)
```

### Idempotency and Performance

- The function is idempotent: running it twice produces the same result as running it once
- It scans only `opencode.json` (one file read) and checks `{file:...}` paths (bounded by number of agents)
- Expected runtime: < 5ms for typical projects with < 50 agents
- No performance concerns for running on every load/unload

### Implementation Target

- File 1: `lua/neotex/plugins/ai/opencode.lua` (or equivalent entry point)
- File 2: `lua/neotex/plugins/ai/shared/extensions/init.lua`
- Lines: near `manager.load()` exit path and `manager.unload()` exit path

---

## Decision 4: Managed Flag Governs Sync Overwrite Behavior

### Current Behavior

`opencode/core/init.lua` lines 50-140 implement a `.managed` sidecar pattern:

- `is_managed()` checks for `.opencode.json.managed` file
- `install_base_opencode_json()` backs up unmanaged files, overwrites managed ones
- Sync (`sync.lua`) uses merge-only semantics for `opencode.json` regardless of managed status

### Design Rule

The `.managed` sidecar governs sync behavior as follows:

1. **Unmanaged files are never overwritten by sync**
   - If `.opencode.json.managed` does not exist, sync must skip `opencode.json` entirely (not even merge-only)
   - Rationale: The user has explicitly customized `opencode.json`; sync should not touch it

2. **Managed files can be replaced during sync-all**
   - If `.opencode.json.managed` exists, sync-all may overwrite with the base template, then re-inject extension agents
   - Rationale: The user has opted into automatic management; sync should keep it up to date

3. **Base template installer respects managed flag**
   - Already implemented in `install_base_opencode_json()` (lines 88-114)
   - No changes needed

### Sidecar File Format

```
opencode.json              # The actual config file
opencode.json.managed      # Sidecar marker file (content: "managed-by: neotex-extensions\n")
opencode.json.user-backup  # Backup of previous unmanaged config
```

### Backup Behavior

- When converting unmanaged -> managed, backup existing config to `opencode.json.user-backup`
- When converting managed -> unmanaged (user removes `.managed` file), do NOT restore backup automatically
- User can manually restore from `opencode.json.user-backup` if desired

### Implementation Target

- File: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- Line: near line 340 (inside `sync_files()` where `opencode.json` action is decided)
- Change: check `is_managed()` before deciding between "skip", "copy", and "replace"

---

## Decision 5: Maintain Current Agent Definition Format

### Current Format

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

### Format Rules (Established by Task 540)

| Attribute | Rule |
|-----------|------|
| Agent name | Filename without `-agent.md` suffix |
| Description | Extracted from agent frontmatter `description` field |
| Mode | `"subagent"` for all extension agents |
| Prompt | `{file:.opencode/agent/subagents/{agent-name}-agent.md}` |
| Tools (research) | read, write, edit, glob, grep, bash, webfetch, websearch |
| Tools (implementation) | write, edit, bash, read, glob, grep |
| Tools (router) | read, grep, glob |
| Tools (other) | full toolset |

### Design Rule

- **No schema changes** to `opencode-agents.json`
- **No changes** to the agent definition format inside `opencode.json`
- The format is adequate for current needs
- Changing it now would require re-generating all 15 extension fragments

### Future Considerations

- If the OpenCode CLI adds new agent attributes, extensions can adopt them incrementally
- The `{file:...}` indirection pattern should be preserved; it enables agent file reuse
- Tool assignment is heuristic (by agent name suffix); formal tool schemas are deferred

---

## Transient State Window Mitigation (Finding 6)

### Problem

During sync-all, the following sequence occurs:

1. Sync replaces `opencode.json` with base template (if managed)
2. Re-injection adds back extension agents
3. `install_base_opencode_json` runs via `on_load_all` callback

Between steps 1 and 2, `opencode.json` temporarily lacks extension agents. If another process reads the file during this window, it sees an incomplete config.

### Mitigation Design

1. **Re-injection must run atomically after any full replace**
   - In `sync.lua`, ensure `reinject_loaded_extensions()` is called immediately after the base template is written
   - Do not yield or call external functions between the write and re-injection

2. **`on_load_all` callback ordering**
   - The callback should run AFTER re-injection completes
   - Currently this is the case (see `sync.lua` lines 1139-1142 and `shared/picker/config.lua` lines 91-98)
   - Document this ordering as a requirement, not an accident

3. **No additional locking needed**
   - Neovim is single-threaded; the transient window is bounded to Lua execution time
   - External processes reading `opencode.json` during sync are rare

### Implementation Target

- File: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- Line: near line 872 (document the ordering requirement in comments)

---

## Validation Checklist

This design spec addresses all 8 findings, 5 decisions, and 6 recommendations from the research report:

| Finding | Status | Section |
|---------|--------|---------|
| Finding 1: Schema already supports opencode_json | Addressed | Decision 5 |
| Finding 2: Merge/unmerge uses key-based tracking | Addressed | Decision 1 (edge cases) |
| Finding 3: Validation has three gaps | Addressed | Decision 2 |
| Finding 4: Agent format is informal | Addressed | Decision 5 (documented rules) |
| Finding 5: Conflict resolution undefined | Addressed | Decision 1 |
| Finding 6: Sync ordering dependencies | Addressed | Transient State Window |
| Finding 7: Cleanup not triggered | Addressed | Decision 3 |
| Finding 8: Managed/unmanaged incomplete | Addressed | Decision 4 |

| Recommendation | Status | Section |
|----------------|--------|---------|
| High: Implement conflict detection | Deferred to implementation | Decision 1 |
| High: Add fragment-to-manifest verification | Deferred to implementation | Decision 2 |
| High: Wire startup cleanup | Deferred to implementation | Decision 3 |
| Medium: Respect managed flag in sync | Deferred to implementation | Decision 4 |
| Medium: Create agent name registry | Addressed in Phase 2 | Reference doc |
| Low: Computed artifact | Deferred | Decision 5 (future) |

---

## References

- Research report: `specs/541_design_opencode_json_agent_registration/reports/01_opencode-json-agent-registration-design.md`
- Task 540 plan: `specs/540_research_opencode_json_and_extension_gaps/plans/01_opencode-json-plan.md`
- Merge implementation: `lua/neotex/plugins/ai/shared/extensions/merge.lua`
- Manager implementation: `lua/neotex/plugins/ai/shared/extensions/init.lua`
- Sync implementation: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- Verify implementation: `lua/neotex/plugins/ai/shared/extensions/verify.lua`
- Base installer: `lua/neotex/plugins/ai/opencode/core/init.lua`
- Core manifest: `.opencode/extensions/core/manifest.json`
- Core agents fragment: `.opencode/extensions/core/opencode-agents.json`

---

## Change Log

- 2026-05-07: Initial design specification created
