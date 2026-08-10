# Task 534 Research Report: Sync Extension Routing Tables

**Date**: 2026-05-07
**Status**: researched

## 1. Executive Summary

The `/implement`, `/research`, and `/plan` command documentation contains Extension-Based Routing Tables that are **significantly out of sync** with the actual extension manifests. Multiple extensions with routing entries are missing from the tables, and several table entries reference task types with no corresponding manifest routing entries. Additionally, numerous extensions provide skills but lack any routing configuration in their manifests entirely.

## 2. Current Command Routing Tables

### 2.1 `/implement` Command (`.opencode/commands/implement.md`)

| Language | Skill to Invoke |
|----------|-----------------|
| `founder` | `skill-founder-implement` (from founder extension) |
| `founder:deck` | `skill-deck-implement` (from founder extension) |
| `founder:{sub-type}` | Compound key lookup, falls back to `skill-founder-implement` |
| `general`, `meta`, `markdown` | `skill-implementer` (default) |
| `formal`, `logic`, `math`, `physics` | `skill-implementer` (default) |

### 2.2 `/research` Command (`.opencode/commands/research.md`)

| Task Type | Skill to Invoke |
|-----------|-----------------|
| `founder` | `skill-market` (from founder extension) |
| `founder:deck` | `skill-deck-research` (from founder extension) |
| `founder:analyze` | `skill-analyze` (from founder extension) |
| `founder:strategy` | `skill-strategy` (from founder extension) |
| `founder:{sub-type}` | Compound key lookup, falls back to `skill-market` |
| `general`, `meta`, `markdown` | `skill-researcher` (default) |

### 2.3 `/plan` Command (`.opencode/commands/plan.md`)

| Task Type | Skill to Invoke |
|-----------|-----------------|
| `founder` | `skill-founder-plan` (from founder extension) |
| `founder:deck` | `skill-deck-plan` (from founder extension) |
| `founder:{sub-type}` | Compound key lookup, falls back to `skill-founder-plan` |
| Other | `skill-planner` (default) |

## 3. Extension Manifest Routing Inventory

### 3.1 Manifests WITH Routing Sections

#### `founder` extension
- **research**: `founder` -> `skill-market`, `founder:market` -> `skill-market`, `founder:analyze` -> `skill-analyze`, `founder:strategy` -> `skill-strategy`, `founder:legal` -> `skill-legal`, `founder:project` -> `skill-project`, `founder:sheet` -> `skill-founder-spreadsheet`, `founder:finance` -> `skill-finance`, `founder:financial-analysis` -> `skill-financial-analysis`, `founder:deck` -> `skill-deck-research`, `founder:meeting` -> `skill-meeting`, `founder:consult` -> `skill-consult`
- **plan**: `founder` -> `skill-founder-plan`, `founder:market` -> `skill-founder-plan`, `founder:analyze` -> `skill-founder-plan`, `founder:strategy` -> `skill-founder-plan`, `founder:legal` -> `skill-founder-plan`, `founder:project` -> `skill-founder-plan`, `founder:sheet` -> `skill-founder-plan`, `founder:finance` -> `skill-founder-plan`, `founder:financial-analysis` -> `skill-founder-plan`, `founder:deck` -> `skill-deck-plan`, `founder:meeting` -> `skill-founder-plan`, `founder:consult` -> `skill-founder-plan`
- **implement**: `founder` -> `skill-founder-implement`, `founder:market` -> `skill-founder-implement`, `founder:analyze` -> `skill-founder-implement`, `founder:strategy` -> `skill-founder-implement`, `founder:legal` -> `skill-founder-implement`, `founder:project` -> `skill-founder-implement`, `founder:sheet` -> `skill-founder-implement`, `founder:finance` -> `skill-founder-implement`, `founder:financial-analysis` -> `skill-founder-implement`, `founder:deck` -> `skill-deck-implement`, `founder:meeting` -> `skill-founder-implement`, `founder:consult` -> `skill-founder-implement`

#### `present` extension
- **research**: `present` -> `skill-grant`, `present:grant` -> `skill-grant`, `present:budget` -> `skill-budget`, `present:timeline` -> `skill-timeline`, `present:funds` -> `skill-funds`, `present:slides` -> `skill-slides`
- **plan**: `present` -> `skill-planner`, `present:grant` -> `skill-planner`, `present:budget` -> `skill-planner`, `present:timeline` -> `skill-planner`, `present:funds` -> `skill-planner`, `present:slides` -> `skill-slide-planning`, `slides` -> `skill-slide-planning`
- **implement**: `present` -> `skill-grant`, `present:grant` -> `skill-grant:assemble`, `present:budget` -> `skill-budget`, `present:timeline` -> `skill-timeline`, `present:funds` -> `skill-funds`, `present:slides` -> `skill-slides:assemble`
- **critique**: `present:slides` -> `skill-slide-critic`

#### `typst` extension
- **research**: `typst` -> `skill-typst-research`
- **implement**: `typst` -> `skill-typst-implementation`

#### `nvim` extension
- **research**: `neovim` -> `skill-neovim-research`
- **implement**: `neovim` -> `skill-neovim-implementation`

#### `lean` extension
- **research**: `lean` -> `skill-lean-research`, `lean4` -> `skill-lean-research`
- **implement**: `lean` -> `skill-lean-implementation`, `lean4` -> `skill-lean-implementation`

#### `core` extension
- `routing_exempt: true` -- not included in extension routing

### 3.2 Manifests WITHOUT Routing Sections (Skills Exist But No Routing)

The following extensions have skills but **no `routing` section** in their manifest:

| Extension | Available Skills | Missing From Tables |
|-----------|-----------------|---------------------|
| `z3` | `skill-z3-research`, `skill-z3-implementation` | All (no routing) |
| `web` | `skill-web-research`, `skill-web-implementation`, `skill-tag` | All (no routing) |
| `python` | `skill-python-research`, `skill-python-implementation` | All (no routing) |
| `nix` | `skill-nix-research`, `skill-nix-implementation` | All (no routing) |
| `latex` | `skill-latex-research`, `skill-latex-implementation` | All (no routing) |
| `formal` | `skill-formal-research`, `skill-logic-research`, `skill-math-research`, `skill-physics-research` | All (no routing) |
| `filetypes` | `skill-filetypes`, `skill-spreadsheet`, `skill-presentation`, `skill-deck` | All (no routing) |
| `epidemiology` | `skill-epidemiology-research`, `skill-epidemiology-implementation` | All (no routing) |
| `memory` | `skill-memory` | All (no routing) |
| `slidev` | (none) | N/A |

## 4. Missing Task Types in Routing Tables

### 4.1 Missing from `/implement` table

The following task types have manifest routing entries but are **not listed** in the `/implement` routing table:

| Task Type | Skill | Extension |
|-----------|-------|-----------|
| `typst` | `skill-typst-implementation` | typst |
| `neovim` | `skill-neovim-implementation` | nvim |
| `lean` | `skill-lean-implementation` | lean |
| `lean4` | `skill-lean-implementation` | lean |
| `present` | `skill-grant` | present |
| `present:grant` | `skill-grant:assemble` | present |
| `present:budget` | `skill-budget` | present |
| `present:timeline` | `skill-timeline` | present |
| `present:funds` | `skill-funds` | present |
| `present:slides` | `skill-slides:assemble` | present |
| `founder:legal` | `skill-founder-implement` | founder |
| `founder:project` | `skill-founder-implement` | founder |
| `founder:sheet` | `skill-founder-implement` | founder |
| `founder:finance` | `skill-founder-implement` | founder |
| `founder:financial-analysis` | `skill-founder-implement` | founder |
| `founder:meeting` | `skill-founder-implement` | founder |
| `founder:consult` | `skill-founder-implement` | founder |

### 4.2 Missing from `/research` table

The following task types have manifest routing entries but are **not listed** in the `/research` routing table:

| Task Type | Skill | Extension |
|-----------|-------|-----------|
| `typst` | `skill-typst-research` | typst |
| `neovim` | `skill-neovim-research` | nvim |
| `lean` | `skill-lean-research` | lean |
| `lean4` | `skill-lean-research` | lean |
| `present` | `skill-grant` | present |
| `present:grant` | `skill-grant` | present |
| `present:budget` | `skill-budget` | present |
| `present:timeline` | `skill-timeline` | present |
| `present:funds` | `skill-funds` | present |
| `present:slides` | `skill-slides` | present |
| `founder:legal` | `skill-legal` | founder |
| `founder:project` | `skill-project` | founder |
| `founder:sheet` | `skill-founder-spreadsheet` | founder |
| `founder:finance` | `skill-finance` | founder |
| `founder:financial-analysis` | `skill-financial-analysis` | founder |
| `founder:meeting` | `skill-meeting` | founder |
| `founder:consult` | `skill-consult` | founder |

### 4.3 Missing from `/plan` table

The following task types have manifest routing entries but are **not listed** in the `/plan` routing table:

| Task Type | Skill | Extension |
|-----------|-------|-----------|
| `present` | `skill-planner` | present |
| `present:grant` | `skill-planner` | present |
| `present:budget` | `skill-planner` | present |
| `present:timeline` | `skill-planner` | present |
| `present:funds` | `skill-planner` | present |
| `present:slides` | `skill-slide-planning` | present |
| `slides` | `skill-slide-planning` | present |
| `founder:market` | `skill-founder-plan` | founder |
| `founder:analyze` | `skill-founder-plan` | founder |
| `founder:strategy` | `skill-founder-plan` | founder |
| `founder:legal` | `skill-founder-plan` | founder |
| `founder:project` | `skill-founder-plan` | founder |
| `founder:sheet` | `skill-founder-plan` | founder |
| `founder:finance` | `skill-founder-plan` | founder |
| `founder:financial-analysis` | `skill-founder-plan` | founder |
| `founder:meeting` | `skill-founder-plan` | founder |
| `founder:consult` | `skill-founder-plan` | founder |

## 5. Orphaned Table Entries (No Manifest Routing)

The following entries appear in the command routing tables but have **no corresponding routing entry** in any extension manifest:

| Command | Task Type | Listed Skill | Issue |
|---------|-----------|--------------|-------|
| `/implement` | `formal` | `skill-implementer` (default) | `formal` extension has NO routing section |
| `/implement` | `logic` | `skill-implementer` (default) | No manifest routes `logic` |
| `/implement` | `math` | `skill-implementer` (default) | No manifest routes `math` |
| `/implement` | `physics` | `skill-implementer` (default) | No manifest routes `physics` |
| `/research` | `markdown` | `skill-researcher` (default) | No manifest routes `markdown` |

**Note**: These task types would correctly fall through to the default skill due to the fallback logic, but listing them in the Extension-Based Routing Table is misleading because it implies explicit extension routing when none exists.

## 6. Extensions Missing Routing Sections Entirely

The following extensions have skills available but lack `routing` sections in their manifests. To be included in the routing tables, these extensions need routing added to their manifests:

| Extension | Skills Available | Action Needed |
|-----------|-----------------|---------------|
| `z3` | `skill-z3-research`, `skill-z3-implementation` | Add routing to manifest |
| `web` | `skill-web-research`, `skill-web-implementation` | Add routing to manifest |
| `python` | `skill-python-research`, `skill-python-implementation` | Add routing to manifest |
| `nix` | `skill-nix-research`, `skill-nix-implementation` | Add routing to manifest |
| `latex` | `skill-latex-research`, `skill-latex-implementation` | Add routing to manifest |
| `formal` | `skill-formal-research`, `skill-logic-research`, `skill-math-research`, `skill-physics-research` | Add routing to manifest |
| `filetypes` | `skill-filetypes`, `skill-spreadsheet`, `skill-presentation`, `skill-deck` | Add routing to manifest |
| `epidemiology` | `skill-epidemiology-research`, `skill-epidemiology-implementation` | Add routing to manifest |

## 7. Skills Inventory

### 7.1 Core Skills (`.opencode/skills/`)

- `skill-fix-it`
- `skill-git-workflow`
- `skill-implementer`
- `skill-learn`
- `skill-memory`
- `skill-meta`
- `skill-orchestrator`
- `skill-planner`
- `skill-project-overview`
- `skill-refresh`
- `skill-researcher`
- `skill-reviser`
- `skill-spawn`
- `skill-status-sync`
- `skill-tag`
- `skill-team-implement`
- `skill-team-plan`
- `skill-team-research`
- `skill-todo`

### 7.2 Legacy/Override Skills (`.claude/skills/`)

- `skill-fix-it`
- `skill-git-workflow`
- `skill-implementer`
- `skill-memory`
- `skill-meta`
- `skill-neovim-implementation`
- `skill-neovim-research`
- `skill-nix-implementation`
- `skill-nix-research`
- `skill-orchestrator`
- `skill-planner`
- `skill-project-overview`
- `skill-refresh`
- `skill-researcher`
- `skill-reviser`
- `skill-spawn`
- `skill-status-sync`
- `skill-tag`
- `skill-team-implement`
- `skill-team-plan`
- `skill-team-research`
- `skill-todo`

### 7.3 Extension Skills (`.opencode/extensions/*/skills/`)

**core**: `skill-implementer`, `skill-orchestrator`, `skill-team-implement`, `skill-git-workflow`, `skill-status-sync`, `skill-spawn`, `skill-tag`, `skill-reviser`, `skill-team-research`, `skill-team-plan`, `skill-planner`, `skill-meta`, `skill-researcher`, `skill-todo`, `skill-refresh`, `skill-project-overview`, `skill-fix-it`

**nix**: `skill-nix-research`, `skill-nix-implementation`

**nvim**: `skill-neovim-implementation`, `skill-neovim-research`

**lean**: `skill-lean-implementation`, `skill-lean-research`, `skill-lake-repair`, `skill-lean-version`

**typst**: `skill-typst-implementation`, `skill-typst-research`

**filetypes**: `skill-presentation`, `skill-filetypes`, `skill-deck`, `skill-spreadsheet`

**present**: `skill-slide-planning`, `skill-timeline`, `skill-budget`, `skill-slides`, `skill-slide-critic`, `skill-funds`, `skill-grant`

**z3**: `skill-z3-implementation`, `skill-z3-research`

**epidemiology**: `skill-epidemiology-implementation`, `skill-epidemiology-research`

**formal**: `skill-logic-research`, `skill-formal-research`, `skill-math-research`, `skill-physics-research`

**latex**: `skill-latex-research`, `skill-latex-implementation`

**founder**: `skill-finance`, `skill-strategy`, `skill-project`, `skill-financial-analysis`, `skill-founder-spreadsheet`, `skill-deck-implement`, `skill-legal`, `skill-consult`, `skill-analyze`, `skill-founder-plan`, `skill-founder-implement`, `skill-deck-plan`, `skill-meeting`, `skill-market`, `skill-deck-research`

**web**: `skill-tag`, `skill-web-research`, `skill-web-implementation`

**python**: `skill-python-research`, `skill-python-implementation`

**memory**: `skill-memory`

## 8. Anti-Bypass Constraint Documentation

### 8.1 `/implement` Command

> **PROHIBITION**: You MUST NOT write implementation summary artifacts directly using Write or Edit tools. All summary files MUST be created by invoking the appropriate skill (skill-implementer or skill-team-implement) via the Skill tool.
>
> **Why**: Direct writes bypass format enforcement (validate-artifact.sh), produce non-conforming artifacts missing required metadata fields and sections, and circumvent the delegation chain that ensures quality. A PostToolUse hook monitors all Write/Edit operations to artifact paths and will flag violations with corrective context.
>
> **Required**: Always delegate to the Skill tool. Never write to `specs/*/summaries/*.md` directly from this command.

### 8.2 `/research` Command

> **PROHIBITION**: You MUST NOT write research report artifacts directly using Write or Edit tools. All report files MUST be created by invoking the appropriate skill (skill-researcher or skill-team-research) via the Skill tool.
>
> **Why**: Direct writes bypass format enforcement (validate-artifact.sh), produce non-conforming artifacts missing required metadata fields and sections, and circumvent the delegation chain that ensures quality. A PostToolUse hook monitors all Write/Edit operations to artifact paths and will flag violations with corrective context.
>
> **Required**: Always delegate to the Skill tool. Never write to `specs/*/reports/*.md` directly from this command.

### 8.3 `/plan` Command

> **PROHIBITION**: You MUST NOT write plan artifacts directly using Write or Edit tools. All plan files MUST be created by invoking the appropriate skill (skill-planner or skill-team-plan) via the Skill tool.
>
> **Why**: Direct writes bypass format enforcement (validate-artifact.sh), produce non-conforming artifacts missing required metadata fields and sections, and circumvent the delegation chain that ensures quality. A PostToolUse hook monitors all Write/Edit operations to artifact paths and will flag violations with corrective context.
>
> **Required**: Always delegate to the Skill tool. Never write to `specs/*/plans/*.md` directly from this command.

## 9. Recommendations

1. **Update `/implement` routing table** to include: `typst`, `neovim`, `lean`, `lean4`, `present` (and all subtypes), and all `founder` subtypes.

2. **Update `/research` routing table** to include: `typst`, `neovim`, `lean`, `lean4`, `present` (and all subtypes), and all `founder` subtypes.

3. **Update `/plan` routing table** to include: `present` (and all subtypes), `slides`, and all `founder` subtypes.

4. **Remove or clarify orphaned entries**: The `formal`, `logic`, `math`, `physics` entries in `/implement` and `markdown` in `/research` should either be removed from the Extension-Based Routing Table or moved to a "Default Fallback" section to avoid implying explicit extension routing.

5. **Add routing to extension manifests**: Consider adding `routing` sections to `z3`, `web`, `python`, `nix`, `latex`, `formal`, `filetypes`, and `epidemiology` manifests so their skills can be used via the extension routing system.
