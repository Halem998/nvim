# Research Report: Task #185

**Task**: 185 - remove_extension_commands_from_core_system
**Started**: 2026-03-11T00:00:00Z
**Completed**: 2026-03-11T00:15:00Z
**Effort**: 1-2 hours (implementation)
**Dependencies**: None
**Sources/Inputs**: Codebase exploration of .opencode/ directory structure
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

- 7 commands in core `.opencode/commands/` belong in extensions: `convert.md`, `deck.md`, `lake.md`, `lean.md`, `slides.md`, `table.md`, `tag.md`
- 2 core skills are duplicated in extensions: `skill-tag` (web), `skill-learn` (memory)
- `research.md` and `implement.md` contain full extension routing tables (12+ extension languages) that should be reduced to 3 core entries (general, meta, markdown)
- Extensions already declare their commands in `manifest.json` but have no `commands/` directories (except memory) -- the extension loader needs to support command merging
- AGENTS.md already has the correct pattern for core-only routing; commands need to match

## Context and Scope

The `.opencode/` system is designed with a core + extensions architecture. Extensions live in `.opencode/extensions/{name}/` and declare their provided assets (agents, skills, commands, rules, context) in `manifest.json`. However, several extension-specific commands currently sit in the core `commands/` directory, and the routing tables in `research.md` and `implement.md` hardcode all extension languages instead of only listing core routes.

This research identifies exactly what needs to move, what can stay, and how the routing tables should be restructured.

## Findings

### 1. Commands Audit

**Current core commands** (19 total in `.opencode/commands/`):

| Command | Should Be | Reason |
|---------|-----------|--------|
| `task.md` | CORE | Task management infrastructure |
| `research.md` | CORE | Research workflow infrastructure |
| `plan.md` | CORE | Planning workflow infrastructure |
| `implement.md` | CORE | Implementation workflow infrastructure |
| `revise.md` | CORE | Plan revision infrastructure |
| `review.md` | CORE | Codebase review infrastructure |
| `todo.md` | CORE | Task archival infrastructure |
| `errors.md` | CORE | Error analysis infrastructure |
| `meta.md` | CORE | System builder infrastructure |
| `fix.md` | CORE | Tag scanning (language-agnostic) |
| `refresh.md` | CORE | Process cleanup (language-agnostic) |
| `convert.md` | EXTENSION (filetypes) | Document format conversion |
| `deck.md` | EXTENSION (filetypes) | Pitch deck creation |
| `slides.md` | EXTENSION (filetypes) | Presentation slides |
| `table.md` | EXTENSION (filetypes) | Spreadsheet/table manipulation |
| `lake.md` | EXTENSION (lean) | Lake build system commands |
| `lean.md` | EXTENSION (lean) | Lean 4 proof commands |
| `tag.md` | EXTENSION (web) | Semantic version tagging for CI/CD |

**Result**: 11 commands should remain in core, 7 commands should move to their respective extensions.

### 2. Skills Audit

**Current core skills** (13 total in `.opencode/skills/`):

| Skill | Should Be | Reason |
|-------|-----------|--------|
| `skill-researcher` | CORE | General research delegation |
| `skill-planner` | CORE | Plan creation delegation |
| `skill-implementer` | CORE | General implementation delegation |
| `skill-meta` | CORE | Meta system building |
| `skill-status-sync` | CORE | Status update utility |
| `skill-refresh` | CORE | Cleanup utility |
| `skill-git-workflow` | CORE | Git commit utility |
| `skill-fix` | CORE | Tag scanning utility |
| `skill-todo` | CORE | Task archival utility |
| `skill-orchestrator` | CORE | Command routing utility |
| `skill-tag` | EXTENSION (web) | CI/CD tagging -- already exists in web extension |
| `skill-learn` | EXTENSION (memory) | Memory vault scanning -- already exists in memory extension |

**Result**: 11 skills should remain in core, 2 skills should move to extensions.

**Note**: `skill-tag` already exists in both core (`skills/skill-tag/`) and web extension (`extensions/web/skills/skill-tag/`). Similarly, `skill-learn` is in core but the memory extension declares `skill-memory`. The `learn.md` command was already moved to the memory extension's `commands/` directory but the core skill-learn remains.

### 3. Agents Audit

**Current core agents** (5 in `.opencode/agent/subagents/`):

| Agent | Should Be | Reason |
|-------|-----------|--------|
| `general-research-agent.md` | CORE | Handles general/meta/markdown research |
| `general-implementation-agent.md` | CORE | Handles general/meta/markdown implementation |
| `planner-agent.md` | CORE | Creates implementation plans |
| `meta-builder-agent.md` | CORE | System building |
| `code-reviewer-agent.md` | CORE | Code review |

**Result**: All 5 core agents are correctly placed. Extension-specific agents (lean-research-agent, neovim-implementation-agent, etc.) are already in their respective extension directories.

### 4. Routing Tables in research.md

**Current state** (lines 101-148): Contains 14 language entries mapping to extension-specific skills and agents, hardcoded directly in the command file.

**Core-only routing** should be:

```
| Language | Skill |
|----------|-------|
| general, meta, markdown | skill-researcher |
```

The same pattern applies to the delegation requirement table and the agent verification table. All three tables in research.md currently have 14+ rows that should be reduced to a single core row.

### 5. Routing Tables in implement.md

**Current state** (lines 82-93): Contains 10 language entries, similarly hardcoded.

**Core-only routing** should be:

```
| Language | Skill |
|----------|-------|
| general, meta, markdown, formal, logic, math, physics | skill-implementer |
```

Note: formal/logic/math/physics route to skill-implementer (the general agent), not to extension-specific agents. This is correct for core -- the formal extension provides research agents but implementation uses the general agent.

### 6. Extension Loader and Command Merging

**Current extension structure**: Extensions declare commands in `manifest.json` under `provides.commands`, but:
- Most extensions do NOT have a `commands/` subdirectory (only memory does)
- Commands declared in manifests currently live in the core `commands/` directory
- The extension loader needs to be updated (or already handles this) to copy/symlink commands from extension directories when loaded

**What needs to happen**:
1. Create `commands/` directories in lean and filetypes extensions
2. Move the 7 extension commands from core to their extension `commands/` directories
3. Ensure the extension loader merges commands from `extensions/{name}/commands/` into the active command set when an extension is loaded

**Memory extension pattern**: The memory extension already has the correct structure -- `extensions/memory/commands/learn.md` exists. The lean and filetypes extensions need to follow this pattern.

### 7. AGENTS.md Analysis

AGENTS.md (the system prompt/configuration file) already has a partially correct pattern:
- Line 58: Lists only `general` and `meta` as core languages (correct, though missing `markdown`)
- Line 80: Lists `/convert` in the command table (should be removed)
- Lines 84-99: Core skill-to-agent mapping is correct
- Line 99: Notes "Extension Skills: When extensions are loaded..." (correct pattern)

However, AGENTS.md still references `/convert` as a core command (line 80).

### 8. Extension Route Injection Design

The recommended approach for extension route injection:

**Option A - Static injection via EXTENSION.md merge**: Each extension's `EXTENSION.md` contains routing table rows. When loaded, these rows are appended to the relevant tables in research.md and implement.md. This is consistent with how AGENTS.md extensions already work via `merge_targets.opencode_md`.

**Option B - Dynamic lookup**: Commands use a fallback: check core routing table first, then scan loaded extensions' manifests for language matches. More flexible but adds runtime complexity.

**Recommendation**: Option A is simpler and consistent with the existing merge pattern. Each extension's EXTENSION.md should include a "Routing Entries" section that gets injected into the command routing tables when the extension loads.

However, the simplest approach is: **have the core routing tables contain ONLY core routes, and add a comment/instruction telling the system to check loaded extensions for additional routes**. The research.md and implement.md commands already have skill tool delegation -- if a language is not in the core table, the command should check `extensions/*/manifest.json` for a matching language and use that extension's skill.

## Recommendations

### Phase 1: Move Commands to Extensions

1. Create `commands/` directories in lean and filetypes extensions
2. Move commands:
   - `convert.md`, `deck.md`, `slides.md`, `table.md` -> `extensions/filetypes/commands/`
   - `lake.md`, `lean.md` -> `extensions/lean/commands/`
   - `tag.md` -> `extensions/web/commands/`
3. Delete the moved files from core `commands/`

### Phase 2: Move Skills to Extensions

1. Move `skill-tag/` from core `skills/` to `extensions/web/skills/` (or verify it already exists there and just delete core copy)
2. Move `skill-learn/` from core `skills/` to `extensions/memory/skills/` (or verify and delete)

### Phase 3: Simplify Routing Tables

1. In `research.md`: Replace the 14-row routing table (lines 101-148) with a single core entry for `general, meta, markdown` -> `skill-researcher`, plus a dynamic lookup instruction for extension languages
2. In `implement.md`: Replace the 10-row routing table (lines 82-93) with core entries only, plus dynamic lookup
3. Similarly simplify the delegation requirement tables and agent verification tables in both files

### Phase 4: Update AGENTS.md

1. Remove `/convert` from command reference table (line 80)
2. Verify language routing section lists only core languages
3. Add `markdown` to core language list if missing

### Phase 5: Update Extension Manifests

1. Verify all moved commands are listed in their extension's `manifest.json`
2. Ensure the web extension manifest lists `tag.md` in `provides.commands` (already does)

## Decisions

- Core languages are: `general`, `meta`, `markdown`
- The `formal`, `logic`, `math`, `physics` languages route to core `skill-implementer` for implementation but should use extension skills for research
- `skill-fix` and `skill-learn` are separate concerns: `skill-fix` scans for tags and creates tasks (core), `skill-learn` was a predecessor that also exists in memory extension context
- `tag.md` is web-specific (CI/CD deployment) and belongs in the web extension

## Risks and Mitigations

- **Risk**: Extension loader may not support command directory merging yet
  - **Mitigation**: Verify how `<leader>ao` extension loading works; may need to update the loader
- **Risk**: Breaking existing workflows that reference extension commands
  - **Mitigation**: Extensions are loaded by default for this project; commands will still be available, just sourced from extension directories
- **Risk**: Dynamic routing lookup adds complexity to research.md/implement.md
  - **Mitigation**: Keep the lookup simple -- a jq query on loaded extension manifests, with clear fallback to general-research-agent

## Appendix

### Files to Move

```
# From core to filetypes extension
.opencode/commands/convert.md -> .opencode/extensions/filetypes/commands/convert.md
.opencode/commands/deck.md -> .opencode/extensions/filetypes/commands/deck.md
.opencode/commands/slides.md -> .opencode/extensions/filetypes/commands/slides.md
.opencode/commands/table.md -> .opencode/extensions/filetypes/commands/table.md

# From core to lean extension
.opencode/commands/lake.md -> .opencode/extensions/lean/commands/lake.md
.opencode/commands/lean.md -> .opencode/extensions/lean/commands/lean.md

# From core to web extension
.opencode/commands/tag.md -> .opencode/extensions/web/commands/tag.md

# Core skills to remove (duplicates in extensions)
.opencode/skills/skill-tag/ -> already in .opencode/extensions/web/skills/skill-tag/
.opencode/skills/skill-learn/ -> already in .opencode/extensions/memory/skills/skill-memory/
```

### Routing Table Before/After

**research.md core routing (after)**:
```
| Language | Skill |
|----------|-------|
| general, meta, markdown | skill-researcher |
```
+ dynamic extension lookup for unmatched languages

**implement.md core routing (after)**:
```
| Language | Skill |
|----------|-------|
| general, meta, markdown, formal, logic, math, physics | skill-implementer |
```
+ dynamic extension lookup for unmatched languages
