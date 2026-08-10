# Research Report: Add default_task_type support to task creation pipeline

- **Task**: 668 - Add default_task_type support to task creation pipeline
- **Started**: 2026-06-12T06:10:00Z
- **Completed**: 2026-06-12T06:20:00Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Sources/Inputs**:
  - `.claude/commands/task.md` (full file, keyword detection at lines 111-131)
  - `.claude/extensions/core/commands/task.md` (extension copy, identical)
  - `.claude/context/reference/state-management-schema.md`
  - `.claude/rules/state-management.md`
  - `specs/state.json` (nvim project)
  - `/home/benjamin/Projects/cslib/specs/state.json` (cslib project)
  - `.claude/extensions/cslib/manifest.json`
  - `.claude/CLAUDE.md` (state.json schema section)
- **Artifacts**: `specs/668_add_default_task_type_support/reports/01_default-task-type.md`
- **Standards**: report-format.md

## Executive Summary

- Step 4 of task.md uses a hardcoded keyword-to-task_type table with no fallback hook for project-level defaults; CSLib tasks get `lean4` or `formal` because those keywords match before any extension type is consulted.
- The best placement for `default_task_type` is as a **top-level field in state.json** (alongside `next_project_number`, `active_topics`), keeping it per-project and consistent with the existing schema design.
- The correct precedence rule is: **meta keywords always win → then use `default_task_type` if set → otherwise use full keyword table → fallback to `general`**; only the `meta` row needs to hard-override since it guards `.claude/` self-modification safety.
- Both `commands/task.md` and `extensions/core/commands/task.md` are byte-identical at step 4, so both must be updated in sync.
- `state-management-schema.md` and the CLAUDE.md `state.json Structure` section both document the schema and must be updated to reflect the new field.

## Context & Scope

The `/task` command (task.md) creates new tasks and assigns a `task_type` using a 20-row hardcoded keyword table at step 4. The keyword matching is case-insensitive substring search against the task description. The CSLib project has a properly registered `cslib` extension with `task_type: "cslib"` in its manifest, skill routing, agents, rules, and context — but tasks created via `/task` in the cslib project always land on `lean4` or `formal` because CSLib work involves proofs, theorems, modal logic, and Kripke semantics (all of which appear in the keyword table rows for lean4 and formal).

The fix is to let a project declare a `default_task_type` in its own `state.json` that pre-empts the full keyword table, while still allowing `meta` tasks to self-identify (because meta tasks modify `.claude/` and must route to the agent-system skills regardless of the project default).

## Findings

### Finding 1: Exact location of keyword detection logic

**File**: `/home/benjamin/.config/nvim/.claude/commands/task.md` lines 111-131
**Extension copy**: `/home/benjamin/.config/nvim/.claude/extensions/core/commands/task.md` lines 111-131

The two files are identical at this section (confirmed by reading both). Any change must be applied to both files.

The current logic is a simple keyword-to-type mapping with no escape hatch for project-level overrides. The full table (in order):

```
"meta", "agent", "command", "skill"         → meta
"lean", "lean4", "mathlib", "theorem", "proof" → lean4
"latex", "tex", "document", "typeset"       → latex
"typst"                                      → typst
"python", "pytest", "pip"                   → python
"z3", "smt", "solver", "constraint"         → z3
"nix", "nixos", "home-manager", "flake"     → nix
"web", "astro", "tailwind", "cloudflare"    → web
"epidemiology", "epi", "cohort", ...        → epi:study
"formal", "logic", "math", "physics", "modal", "kripke" → formal
"deck", "slide", "presentation", ...        → founder:deck
... (more founder subtypes)
"founder", "go-to-market", "gtm"            → founder
Otherwise                                    → general
```

### Finding 2: Problem diagnosis for CSLib

CSLib task descriptions commonly contain:
- "proof", "theorem", "lean4", "mathlib" → hits `lean4` row
- "logic", "modal", "kripke", "formal" → hits `formal` row

The `cslib` task type is never reached because the generic proof/logic keywords fire first. There is no way to declare "in this project, proof tasks are `cslib`, not `lean4`" without modifying the hardcoded table.

### Finding 3: state.json schema — where to add the field

**Current top-level keys in nvim/specs/state.json** (version 1.1.0):
```json
{
  "version": "1.1.0",
  "next_project_number": 669,
  "active_projects": [...],
  "completed_projects": [],
  "repository_health": {...},
  "memory_health": {...},
  "active_topics": [...]
}
```

**Current top-level keys in cslib/specs/state.json** (no version field):
```json
{
  "next_project_number": 159,
  "active_projects": [...],
  "repository_health": {...},
  "active_topics": [...]
}
```

The correct placement is as a new top-level field `default_task_type` in state.json. This:
- Is per-project (cslib gets `"cslib"`, nvim stays unset or `null`)
- Is already read by the `/task` command's first step: `jq -r '.next_project_number' specs/state.json`
- Is consistent with other global project settings (`active_topics`, `repository_health`)
- Does not require schema versioning changes (optional field, `null` if absent = no override)

The field is **optional**. When absent or `null`, the existing keyword table runs unchanged. When present and non-null, it replaces the keyword table result (except for `meta`).

### Finding 4: Precedence logic

The correct override hierarchy is:

1. **`meta` keywords always fire first** (before checking `default_task_type`)
   - Rationale: "meta", "agent", "command", "skill" identify tasks that modify `.claude/` itself. These must route to meta skills regardless of project type. A cslib project that creates a new skill or command must still be routed as `meta`.
   - Keywords to keep unconditional: `"meta"`, `"agent"`, `"command"`, `"skill"`

2. **`default_task_type` from state.json** (if present and non-null)
   - If description does not match any `meta` keyword, and `default_task_type` is set, use it.
   - This completely replaces the rest of the keyword table for that project.

3. **Full keyword table** (only if no `default_task_type` set)
   - Runs as-is when `default_task_type` is null/absent.
   - Covers all extension keywords (lean4, latex, typst, python, etc.)

4. **`general` fallback** (if nothing matched)

**Why not keep the full keyword table alongside `default_task_type`?**
The whole point is to prevent lean4/formal/etc. from matching. If the full table ran after the default, the user would still need to carefully word descriptions to avoid triggering the wrong type. The default should fully substitute the table.

**Edge case — user explicitly wants to override the default for one task**: The user can pass `--task-type lean4` as an inline flag (step 2 of task.md already has `Extract optional: effort, task_type`). This provides an escape hatch even when `default_task_type` is set.

### Finding 5: Implementation change in task.md step 4

The updated step 4 logic in prose:

```
4. Detect task_type:
   a. Read default_task_type from state.json:
      default=$(jq -r '.default_task_type // empty' specs/state.json)

   b. Check meta keywords first (unconditional):
      if description contains "meta", "agent", "command", or "skill":
        task_type = "meta"

   c. Else if $default is non-empty:
      task_type = $default

   d. Else run full keyword table (unchanged):
      [existing rows...]
      Otherwise → general
```

The jq read is a single-line addition before the keyword check. The `// empty` operator returns empty string when the field is absent or null, which the bash `if [ -n "$default" ]` pattern handles cleanly.

### Finding 6: Extension copy sync

`/home/benjamin/.config/nvim/.claude/extensions/core/commands/task.md` lines 111-131 are byte-for-byte identical to the main `commands/task.md`. Both files must be updated together. The extension copy is the "sync source" used when loading the core extension into child projects — keeping them in sync is essential.

### Finding 7: Documentation locations to update

Three locations document the state.json schema:

1. **`.claude/context/reference/state-management-schema.md`** — The canonical schema reference. The "state.json Full Structure" code block at line 7 and the "Field Reference" table at line 58 both need a `default_task_type` entry. This is the authoritative documentation.

2. **`.claude/CLAUDE.md` state.json Structure section** — The inline snippet in CLAUDE.md that shows the state.json shape. This is auto-generated from extension merge sources, so directly editing CLAUDE.md may be incorrect; the source file (likely an EXTENSION.md or the merge template) should be updated instead. However, since CLAUDE.md says "This file is generated automatically from loaded extensions. Do not edit directly", the update path goes through the merge source. For the nvim project, the state.json snippet in CLAUDE.md is injected via `.claude/extensions/core/EXTENSION.md` or a core extension merge. This needs investigation in the implementation phase.

3. **Extension `EXTENSION.md` files** — If the state.json schema snippet is maintained in an extension EXTENSION.md file, that source should be updated.

### Finding 8: State.json version field

The nvim project state.json has `"version": "1.1.0"` while the cslib project does not have a version field. Adding `default_task_type` is a backward-compatible additive change (optional field, null-safe default). It does not require bumping the schema version, but if version bumping is desired for this additive change, `1.2.0` would be appropriate.

## Decisions

- **Placement**: Top-level field `default_task_type` in state.json (not per-task, not in a separate config file).
- **Type**: Optional string or null. When absent or null = no override (existing behavior preserved).
- **Precedence**: `meta` keywords > `default_task_type` > full keyword table > `general`.
- **Meta is the only unconditional override**: No other keyword row gets special treatment. The user's `--task-type` flag (step 2 inline extraction) provides an explicit per-task override when needed.
- **Both task.md files updated together**: `commands/task.md` and `extensions/core/commands/task.md` are kept in sync.

## Recommendations

1. **Modify task.md step 4** (both files):
   - Add jq read of `default_task_type` at the start of step 4
   - Insert meta-keyword check before the default check
   - Replace the keyword table with the default when non-empty

2. **Add `default_task_type` to state-management-schema.md**:
   - Add entry in the Field Reference table (optional, string or null)
   - Add to the Full Structure example JSON
   - Document the null/absent = no override semantics

3. **Update CLAUDE.md state.json schema snippet**:
   - Locate the merge source for the CLAUDE.md state.json snippet
   - Add `default_task_type` as an optional field in the snippet
   - Regenerate CLAUDE.md via the extension merge tool

4. **Set `default_task_type` in cslib state.json**:
   - Add `"default_task_type": "cslib"` to `/home/benjamin/Projects/cslib/specs/state.json`
   - This is the immediate user-facing benefit of the feature

5. **Leave nvim state.json unchanged** (no `default_task_type` field):
   - The nvim project uses lean4/nix/neovim correctly from the keyword table; no override needed

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| User forgets `meta` still overrides default | Low | Documented in step 4 comment and schema docs |
| Extension copy drifts from main copy | Medium (historical) | Implementation must update both files atomically in same commit |
| State.json version mismatch confusion | Low | Additive field is backward-compatible; no version bump needed |
| CLAUDE.md regeneration overwrites manual edits | Medium | Update only the merge source (EXTENSION.md), not CLAUDE.md directly |
| `jq -r '.default_task_type // empty'` returns literal "null" | Low | Use `// empty` not `// ""` — jq `// empty` returns empty output for JSON null |

## Context Extension Recommendations

- **Topic**: Project-level task type configuration
- **Gap**: No existing context document describes how projects can declare extension-specific defaults for task routing at the project level
- **Recommendation**: After implementation, add a brief note to `.claude/context/patterns/task-type-routing.md` (create if it doesn't exist) documenting the `default_task_type` mechanism as an escape hatch for projects dominated by a single extension type

## Appendix

### Files to Modify

| File | Change |
|------|--------|
| `/home/benjamin/.config/nvim/.claude/commands/task.md` | Step 4: add jq read + precedence logic |
| `/home/benjamin/.config/nvim/.claude/extensions/core/commands/task.md` | Same change (sync copy) |
| `/home/benjamin/.config/nvim/.claude/context/reference/state-management-schema.md` | Add `default_task_type` field documentation |
| CLAUDE.md merge source for state.json snippet | Add `default_task_type` to snippet |
| `/home/benjamin/Projects/cslib/specs/state.json` | Set `"default_task_type": "cslib"` |

### jq Pattern for Reading default_task_type

```bash
default_type=$(jq -r '.default_task_type // empty' specs/state.json)
```

- Returns empty string if field absent or null
- Returns the string value if set (e.g., `"cslib"`)
- Safe with `if [ -n "$default_type" ]` guard

### Exact Step 4 Structure (post-change)

```markdown
4. Detect task_type from keywords:

   a. Read default_task_type from state.json:
      ```bash
      default_type=$(jq -r '.default_task_type // empty' specs/state.json)
      ```

   b. Check meta keywords first (always override):
      - "meta", "agent", "command", "skill" → meta

   c. Else if $default_type is non-empty:
      task_type = $default_type

   d. Else use keyword table:
      - "lean", "lean4", "mathlib", "theorem", "proof" → lean4
      [... rest of existing table unchanged ...]
      - Otherwise → general
```
