# Research Report: Task #599

**Task**: 599 - update_claudemd_extension_documentation
**Started**: 2026-05-22T15:00:00Z
**Completed**: 2026-05-22T15:45:00Z
**Effort**: 1 hour
**Dependencies**: Tasks 593, 594, 595, 596, 597, 598 (all completed)
**Sources/Inputs**:
- Codebase: `lua/neotex/plugins/ai/shared/extensions/merge.lua` (generate_claudemd function)
- Codebase: `lua/neotex/plugins/ai/shared/extensions/init.lua` (load/unload triggers)
- Codebase: `lua/neotex/plugins/ai/shared/extensions/loader.lua` (file copy engine)
- Codebase: `lua/neotex/plugins/ai/shared/extensions/picker.lua` (Telescope picker UI)
- Codebase: `lua/neotex/plugins/editor/which-key.lua` (`<leader>al` binding)
- Codebase: `.claude/scripts/skill-base.sh` (shared lifecycle functions)
- Codebase: `.claude/docs/architecture/architecture-spec.md` (Component 6: Extension Hooks)
- Codebase: `.claude/extensions/core/manifest.json` + `.claude/extensions/nvim/manifest.json`
- Task summaries: 595, 596, 597, 598 implementation summaries
**Artifacts**:
- `specs/599_update_claudemd_extension_documentation/reports/02_claudemd-generation-research.md`
**Standards**: report-format.md, subagent-return.md

---

## Executive Summary

- CLAUDE.md programmatic generation is **already fully implemented** via `merge.lua:generate_claudemd()`. The file is regenerated as a computed artifact on every extension load, unload, and reload — no manual editing required.
- The `<leader>al` picker routes through `ai-tool-picker.lua:show_commands_picker()`, which lets the user choose Claude Code or OpenCode commands (not the extension manager). The extension manager picker is accessible via `:ClaudeExtensions` Vim command and `<C-r>` within the extensions Telescope picker.
- Extension lifecycle hooks (manifest `hooks` object: preflight, context_injection, postflight, verification) are specified in `architecture-spec.md` Component 6 but **have not been implemented** in `skill-base.sh` — the file contains a comment: `# EXTENSION HOOKS: Not implemented in this version (deferred to task 599)`.
- Extension skills (nvim, nix, etc.) remain at **250-412 lines** rather than the target 30-50 lines. They still inline all lifecycle stages instead of delegating to `skill-base.sh`.
- The core `claudemd.md` merge-source is **current** (includes `/orchestrate`, skill-orchestrate, updated routing tables from tasks 595-597). The generated CLAUDE.md matches it.
- Gap summary: (1) hooks schema missing from manifest.json for all extensions; (2) skill-base.sh has no hook invocation; (3) extension skills are not thinned; (4) system-overview.md is dated 2026-01-19 and predates the refactor; (5) docs/guides need hooks documentation.

---

## Context & Scope

Task 599 is the final wave-6 task in the unified workflow refactor series (593-599). All upstream dependencies are complete. This research examines the exact current state of each deliverable in the task description:

1. CLAUDE.md generation mechanism and current state
2. Extension loader system and `<leader>al` picker
3. Extension lifecycle hooks — what the spec says vs. what is implemented
4. Extension manifest schema — current fields and what needs adding
5. Extension skill sizes — current vs. target
6. Documentation gaps in guides

---

## Findings

### 1. CLAUDE.md Generation — Already Fully Implemented

**How it works** (`merge.lua:generate_claudemd`, lines 537-660):

- Starts from `core/templates/claudemd-header.md` (contains "This file is generated automatically...")
- Reads loaded extensions from `extensions.json` state via `state_mod.list_loaded()`
- Builds dependency-ordered list: `core` always first, then others in stable sort order
- For each loaded extension, reads `manifest.merge_targets["claudemd"].source` (e.g., `merge-sources/claudemd.md` for core, `EXTENSION.md` for all others)
- Concatenates fragments with double-newline separation
- Writes the final output to `.claude/CLAUDE.md`

**When triggered** (both `init.lua` load/unload paths):
- After `state_mod.mark_loaded()` writes state: `merge_mod.generate_claudemd(project_dir, config)`
- After `state_mod.mark_unloaded()` writes state: `merge_mod.generate_claudemd(project_dir, config)`
- Also called by `manager.reload()` (unload + load)

**Current CLAUDE.md state**: The generated file correctly includes core content plus `## Neovim Extension` and `## Nix Extension` sections from the currently loaded extensions. The `/orchestrate` command row and `skill-orchestrate` mapping (added in task 596) are present in the merge-source and in the generated output. The file is up to date.

**Key implementation note**: The old section-injection approach (`inject_section`/`remove_section`) is preserved in `merge.lua` for backward compat but is no longer called by the load/unload path. The comment in `init.lua` (line 81-87) explicitly documents this: "Config markdown (CLAUDE.md or OPENCODE.md) is now a computed artifact. Section injection is skipped here."

### 2. Extension Loader System and `<leader>al` Picker

**`<leader>al` does NOT open the extension manager picker** — this is a key finding. `<leader>al` calls `ai-tool-picker.lua:show_commands_picker()`, which presents a `vim.ui.select` prompt asking "ClaudeCode or OpenCode?" It then opens the Claude commands artifacts picker (`:ClaudeCommands`) or OpenCode commands.

**Extension management picker** is separate:
- Lua module: `lua/neotex/plugins/ai/claude/extensions/picker.lua` (thin wrapper over shared picker)
- Invoked via: `:ClaudeExtensions` user command (no dedicated keymap)
- The picker shows all available extensions with `[active]`, `[update]`, or `[inactive]` status
- Enter toggles load/unload; `<C-r>` reloads; `<C-d>` shows installed files

**Extension state persistence**: `extensions.json` (per-project state file tracking which extensions are loaded, what files were installed, what merge sections were added). Located in the project at `.claude/extensions.json`.

**Auto-generation trigger**: CLAUDE.md is regenerated on every load/unload, so CLAUDE.md always reflects what is currently loaded. The generation reads `extensions.json` state to determine which extensions are active.

### 3. Extension Lifecycle Hooks — Architecture Spec vs. Implementation Gap

**Spec** (architecture-spec.md, Component 6):

The spec defines a `hooks` object in `manifest.json`:
```json
"hooks": {
  "preflight": "scripts/nix-preflight.sh",
  "context_injection": "scripts/nix-context.sh",
  "postflight": "scripts/nix-postflight.sh",
  "verification": "scripts/nix-verify.sh"
}
```

Hook invocation points in `skill-base.sh`:
- Stage 2 (`skill_preflight_update`): call `hooks.preflight`
- Stage 4 (`skill_prepare_delegation`): call `hooks.context_injection`
- Stage 6a (`skill_validate_artifact`): call `hooks.verification`
- Stage 7 (`skill_postflight_update`): call `hooks.postflight`

**Current implementation** (`skill-base.sh`, line 24-25):
```bash
# EXTENSION HOOKS: Not implemented in this version (deferred to task 599).
# Future: EXTENSION_PREFLIGHT_HOOK, EXTENSION_CONTEXT_HOOK, EXTENSION_POSTFLIGHT_HOOK
```

**Gap**: Zero hooks implemented. No `skill_prepare_delegation()` function exists in `skill-base.sh`. Hook invocation machinery is entirely absent.

**Current manifest schema for hooks**: Extensions use `"hooks": []` (array of filenames in `provides.hooks`) for the file-copy system — these are shell scripts copied to `.claude/hooks/` directory during extension load. This is the `provides.hooks` array (not the lifecycle `hooks` object). The spec's `hooks` object is a **different, new top-level field** from `provides.hooks`.

### 4. Extension Manifest Schema — Current vs. Target

**Current schema** (nvim extension example):
```json
{
  "name": "nvim",
  "version": "1.0.0",
  "description": "...",
  "task_type": "neovim",
  "dependencies": ["core"],
  "provides": { "agents": [...], "skills": [...], "hooks": [], ... },
  "routing": { "research": {...}, "plan": {...}, "implement": {...} },
  "merge_targets": { "claudemd": {...}, "index": {...}, "opencode_json": {...} },
  "mcp_servers": {}
}
```

**Missing from spec** (Component 6 lifecycle hooks schema):
```json
"hooks": {
  "preflight": "scripts/nix-preflight.sh",
  "context_injection": "scripts/nix-context.sh",
  "postflight": "scripts/nix-postflight.sh",
  "verification": "scripts/nix-verify.sh"
}
```

The top-level `hooks` object (lifecycle hooks) must be distinguished from `provides.hooks` (file-copy hooks). Adding a top-level `"hooks": {}` to manifests would coexist with `provides.hooks` without conflict.

**Extensions requiring hooks schema update**: All 15 extensions with manifests (core, epidemiology, filetypes, formal, founder, latex, lean, memory, nix, nvim, present, python, typst, web, z3). Slidev has no manifest.

### 5. Extension Skill Sizes — Current vs. Target

The architecture spec targets **30-50 lines** for extension skills (vs. 400-600 today), with the body becoming:
1. Frontmatter
2. Stage 4: Call `hooks.context_injection`
3. Stage 5: Invoke subagent with domain-specific `subagent_type`
4. Source `skill-base.sh` for all other stages

**Current sizes**:
| Skill | Lines | Target |
|-------|-------|--------|
| skill-neovim-research | 254 | 30-50 |
| skill-neovim-implementation | 372 | 30-50 |
| skill-nix-research | 254 | 30-50 |
| skill-nix-implementation | 412 | 30-50 |
| skill-latex-research | 73 | 30-50 (close!) |
| skill-latex-implementation | 96 | 30-50 (close!) |
| skill-python-research | 62 | 30-50 (close!) |
| skill-python-implementation | 85 | 30-50 (close!) |
| skill-z3-research | 62 | 30-50 (close!) |
| skill-z3-implementation | 85 | 30-50 (close!) |
| skill-typst-research | 73 | 30-50 |
| skill-typst-implementation | 96 | 30-50 (close) |

**Analysis**: Several simple extension skills (latex, python, z3, typst) are already near the 30-50 line target because they follow the fork pattern (`context: fork`, `agent:` frontmatter) without inlining lifecycle stages. The complex ones (nvim 254-372, nix 254-412) still have full inline lifecycle stages that duplicate what `skill-base.sh` provides.

### 6. Documentation Gaps

**`creating-skills.md`** (715 lines): Describes the thin wrapper pattern accurately for the `context: fork` / Pattern B approach. Does not mention hooks or `skill-base.sh`. The `context: fork` pattern is Pattern B; Pattern A (core skills with explicit Task subagent_type) uses `skill-base.sh`. Extension skills should use Pattern A with hooks.

**`creating-extensions.md`** (716 lines): manifest.json template shows `"hooks": []` in `provides` only. No mention of lifecycle hooks top-level `hooks` object. No guidance on creating hook scripts or thinning extension skills.

**`creating-commands.md`** / `creating-agents.md`**: These are about core commands/agents, less relevant to hooks.

**`system-overview.md`**: Last verified 2026-01-19. Contains a "See Also (Target Architecture)" banner pointing to tasks 593-599. Since all those tasks are now complete, the system-overview needs to be rewritten to describe the **current** (refactored) architecture, removing the "target" framing and integrating:
- `/orchestrate` command and skill-orchestrate state machine
- `skill-base.sh` shared lifecycle
- `command-gate-in.sh`, `command-gate-out.sh`, `command-route-skill.sh`
- Extension hooks lifecycle (if implemented in task 599)

### 7. CLAUDE.md Content Gaps (Core Merge-Source)

The core merge-source `extensions/core/merge-sources/claudemd.md` currently documents:
- `/orchestrate` command (added in task 596) — present
- `skill-orchestrate` in skill-to-agent table — present
- Four-tier context model (should reference task 598) — present but brief

What may need updating after task 599:
- Completion workflow note: "Meta tasks: `completion_summary` only (CLAUDE.md is auto-generated from merge-sources)" — this is accurate but could note the `generate_claudemd()` mechanism
- Status marker list: the current merge-source uses slightly different format than the live CLAUDE.md (minor discrepancy in `[ABANDONED]` terminal state list)

---

## Decisions

- **CLAUDE.md generation is already done**: task 599 does not need to implement generation logic; it needs to (a) add lifecycle hooks machinery to skill-base.sh, (b) update manifests with the hooks schema, (c) optionally thin extension skills, and (d) update documentation.
- **`<leader>al` is NOT the extension loader picker**: The description's focus prompt mentions "loaded in the `<leader>al` picker" but `<leader>al` opens the commands picker, not the extension manager. The extension manager is `:ClaudeExtensions`. This may be an imprecise reference to the general "AI picker" that the user associates with loading extensions.
- **Hook implementation is non-trivial**: `skill-base.sh` needs a new mechanism to read task_type from TASK_TYPE env var, look up the loaded extension manifest for that task_type, find the `hooks` object, and call the hook scripts with positional args. This requires reading `extensions.json` state.
- **Simple extension skills may not need thinning**: Skills like latex/python/z3 at 62-96 lines are already near target. The improvement opportunity is primarily for nvim, nix, web, founder, present, lean, and memory skills.

---

## Recommendations

### Priority 1: Add lifecycle hooks schema to manifest.json (all extensions)

Add a top-level `"hooks": {}` object to each extension's manifest.json. For most extensions this will be an empty object `{}` (hooks are optional per spec). Only extensions that have domain-specific preflight/postflight needs (nix: flake check, lean: lake build) would populate hook scripts.

### Priority 2: Implement hook invocation in skill-base.sh

Add a `skill_run_extension_hook()` helper function:
```bash
skill_run_extension_hook() {
  local hook_name="$1"   # "preflight" | "context_injection" | "postflight" | "verification"
  local task_number="$2"
  local task_type="$3"
  local task_dir="$4"
  local session_id="$5"
  local operation="$6"
  # 1. Read extensions.json to find loaded extension for task_type
  # 2. Read extension manifest for hooks.$hook_name
  # 3. If present and executable, call: bash "$hook_script" "$task_number" "$task_type" "$task_dir" "$session_id" "$operation"
  # 4. Log result; non-fatal (set -e disabled)
}
```
Call sites: inside `skill_preflight_update`, new `skill_context_injection`, `skill_validate_artifact`, `skill_postflight_update`.

### Priority 3: Update creating-extensions.md documentation

Add a "Lifecycle Hooks" section covering:
- Top-level `hooks` object schema
- Hook execution contract (positional args, exit codes)
- Example hook scripts for domain-specific use cases
- Integration with skill-base.sh

### Priority 4: Update system-overview.md

Remove the "target architecture" framing and update to document the completed refactor:
- New scripts: skill-base.sh, command-gate-in.sh, command-gate-out.sh, command-route-skill.sh, dispatch-agent.sh
- New command: `/orchestrate` with skill-orchestrate state machine
- CLAUDE.md as computed artifact from extension merge-sources

### Priority 5 (optional): Thin complex extension skills

For nvim and nix skills specifically, replace inline lifecycle stages with `source skill-base.sh` and hook calls. The simple skills (latex, python, z3, typst) are already near target and should be left as-is unless there is a specific reason to modify them.

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Hook lookup requires reading extensions.json per invocation | Medium | Cache in env var once per skill invocation; or accept small overhead for correctness |
| Extensions.json path differs across projects | Low | Use config.state_file path pattern already used elsewhere |
| Thinning extension skills could break orchestrator_mode flag propagation | Medium | Task 595 summary notes: add orchestrator_mode support to extension skills as a follow-up; ensure hook machinery passes it through |
| Manifest hooks object conflicts with provides.hooks array naming | Low | Use different key names: `hooks` (top-level = lifecycle) vs `provides.hooks` (file-copy = what gets installed) |

---

## Context Extension Recommendations

- **Topic**: Extension lifecycle hooks documentation
- **Gap**: `creating-extensions.md` has no section on the `hooks` top-level manifest field or hook execution contract
- **Recommendation**: Add "Lifecycle Hooks" section to `creating-extensions.md` after implementing hooks in skill-base.sh

- **Topic**: skill-base.sh usage guide for extension skill authors
- **Gap**: `creating-skills.md` describes Pattern B (fork pattern) well but doesn't explain when/how to use `skill-base.sh` (Pattern A) for extension skills
- **Recommendation**: Add a "Using skill-base.sh in Extension Skills" section to `creating-skills.md`

---

## Appendix

### File Sizes for Extension Skills

```
core skills: skill-implementer 645L, skill-planner 506L, skill-researcher 465L
nvim: skill-neovim-research 254L, skill-neovim-implementation 372L
nix: skill-nix-research 254L, skill-nix-implementation 412L
latex: skill-latex-research 73L, skill-latex-implementation 96L
python: skill-python-research 62L, skill-python-implementation 85L
z3: skill-z3-research 62L, skill-z3-implementation 85L
typst: skill-typst-research 73L, skill-typst-implementation 96L
lean: skill-lean-research 247L, skill-lean-implementation 316L
web: skill-web-research 278L, skill-web-implementation 397L
formal: skill-formal-research 131L, skill-logic-research 202L
founder: (complex domain, ~250-363L range)
present: (complex domain, ~344-1051L range)
memory: skill-memory 2482L (special case)
```

### Key Source Files

- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/merge.lua` — `generate_claudemd()` at line 537
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/init.lua` — load/unload trigger at lines 518-525, 659-665
- `/home/benjamin/.config/nvim/.claude/scripts/skill-base.sh` — hook placeholder comment at lines 24-25
- `/home/benjamin/.config/nvim/.claude/docs/architecture/architecture-spec.md` — Component 6 (Extension Hooks) at lines 367-425
- `/home/benjamin/.config/nvim/.claude/extensions/core/merge-sources/claudemd.md` — canonical CLAUDE.md merge source
- `/home/benjamin/.config/nvim/.claude/extensions/nvim/manifest.json` — reference manifest for nvim extension

### Completed Refactor Task Outcomes Relevant to Task 599

| Task | Outcome Relevant to 599 |
|------|------------------------|
| 595 | Commands slimmed; `orchestrator_mode` plumbing added; NOTE in summary: "Add orchestrator_mode support to extension skills" as follow-up |
| 596 | `/orchestrate`, `skill-orchestrate`, `dispatch-agent.sh` created; CLAUDE.md and merge-source updated |
| 597 | `/todo`, `/review`, `/revise`, `/task` refactored; memory harvest added |
| 598 | Context index tiered; all 142 entries classified; budget validation script created |

### CLAUDE.md Generation Evidence

The `<leader>al` / `:ClaudeExtensions` flow is:
1. User opens Claude extension manager (`:ClaudeExtensions`)
2. Selects extension, presses Enter to load
3. `manager.load()` in `init.lua` copies files via `loader.lua`
4. After `state_mod.mark_loaded()`: calls `merge_mod.generate_claudemd()`
5. `generate_claudemd()` reads loaded extensions from state, concatenates their `EXTENSION.md` content
6. Writes to `.claude/CLAUDE.md` atomically
7. CLAUDE.md is now up to date without any manual editing
