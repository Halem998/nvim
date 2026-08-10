# Implementation Plan: Task #682

- **Task**: 682 - Add extension keyword_overrides support to /task command
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/682_extension_keyword_overrides_task_command/reports/01_keyword-overrides-research.md
- **Artifacts**: plans/02_keyword-overrides-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a `keyword_overrides` field to extension manifests that enables extensions to register keywords and type aliases for task creation. The implementation modifies task.md step 4 to scan extension manifests for `keyword_overrides` after the meta keyword check but before the hardcoded keyword table and `default_task_type`. This inserts extension-controlled task-type detection into the existing precedence chain, resulting in: meta keywords > extension keyword_overrides > default_task_type > hardcoded keyword table > general.

### Research Integration

The research report (01_keyword-overrides-research.md) established:
- task.md step 4 is prose instruction, not a shell script; the implementation is descriptive
- No existing manifest has `keyword_overrides`; this is a net-new field
- The scan pattern should mirror `command-route-skill.sh` (glob over `.claude/extensions/*/manifest.json`)
- Aliases remap hardcoded-table results only (not other extensions' keyword results)
- First-match-wins across extensions for deterministic behavior
- `keyword_overrides` is optional (missing = `{}` = no effect)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Enable extensions to register keywords that map to their task type during `/task` creation
- Enable extensions to alias existing keyword table results to their task type
- Maintain backward compatibility (existing manifests without `keyword_overrides` are unaffected)
- Document the new manifest field in extension-development.md

**Non-Goals**:
- Modifying routing scripts (`command-route-skill.sh`, etc.) -- routing is post-creation
- Adding `keyword_overrides` to any existing manifest (task 683 handles the cslib manifest)
- Adding interactive keyword conflict resolution
- Filtering by loaded-only extensions (scan all present manifests, matching routing pattern)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Two extensions claim same keyword | M | L | First-match-wins (glob ordering); recommend specific non-overlapping keywords in docs |
| jq `contains()` doing substring match | M | M | Use `test("\\b" + $kw + "\\b")` or explicit word-boundary matching in scan instructions |
| Prose instructions misinterpreted by agent | M | L | Provide exact jq patterns in the task.md text for reference |
| Core extension copy drift | M | L | Sync copy in same phase as live edit |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Update task.md step 4 with extension keyword_overrides logic [COMPLETED]

**Goal**: Insert extension keyword_overrides scanning into the task-type detection precedence chain in task.md step 4.

**Tasks**:
- [x] Edit `.claude/commands/task.md` step 4 to restructure the precedence chain *(completed)*
- [x] Insert extension keyword_overrides scanning after meta keywords but before `default_task_type` and hardcoded keyword table *(completed)*
- [x] Include explicit jq patterns for the agent to follow when scanning manifests *(completed)*
- [x] Sync the identical change to `.claude/extensions/core/commands/task.md` *(completed: files are byte-identical)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/commands/task.md` - Rewrite step 4 to add extension keyword_overrides scanning between meta keywords and default_task_type/hardcoded table
- `.claude/extensions/core/commands/task.md` - Sync identical change

**Details**:

The current step 4 text (lines 111-140) must be replaced. The new precedence chain is:

```
4. **Detect task_type** from keywords:

   First, check for a project-level default:
   ```bash
   default_type=$(jq -r '.default_task_type // empty' specs/state.json)
   ```

   Then apply precedence rules (first match wins, stop checking):

   **4a. Meta keywords (always win, unconditional)**:
   - "meta", "agent", "command", "skill" in description → task_type = `meta`, done

   **4b. Extension keyword_overrides (scan manifests)**:
   Scan `.claude/extensions/*/manifest.json` for `keyword_overrides` fields.
   For each manifest that has `keyword_overrides`:
   - For each task_type key in `keyword_overrides`:
     - If any string in `keywords` array appears as a whole word in the
       description (case-insensitive) → task_type = that key, done

   Reference jq pattern for keyword scanning:
   ```bash
   for manifest in .claude/extensions/*/manifest.json; do
     [ -f "$manifest" ] || continue
     matched=$(jq -r --arg desc "$description_lower" '
       .keyword_overrides // {} | to_entries[] |
       select(.value.keywords[]? as $kw |
         ($desc | test("\\b" + $kw + "\\b"))) |
       .key' "$manifest" 2>/dev/null | head -1)
     [ -n "$matched" ] && break
   done
   ```
   If `matched` is non-empty → task_type = `matched`, skip to step 4e.

   **4c. Project default** (if `default_type` is non-empty): task_type = `default_type`, skip to step 4e.

   **4d. Hardcoded keyword table** (fallback):
   - "neovim", "plugin", "nvim", "lua" → neovim
   [... rest of existing keyword table unchanged ...]
   - Otherwise → general

   **4e. Extension alias remapping** (post-resolution):
   After 4c or 4d resolves a task_type, scan manifests for alias matches:
   - For each manifest with `keyword_overrides`:
     - For each task_type key: if `aliases` array contains the current
       task_type → remap to the extension's task_type, done

   Reference jq pattern for alias remapping:
   ```bash
   for manifest in .claude/extensions/*/manifest.json; do
     [ -f "$manifest" ] || continue
     aliased=$(jq -r --arg tt "$task_type" '
       .keyword_overrides // {} | to_entries[] |
       select(.value.aliases[]? == $tt) |
       .key' "$manifest" 2>/dev/null | head -1)
     [ -n "$aliased" ] && { task_type="$aliased"; break; }
   done
   ```

   Note: Alias remapping applies only to results from 4c/4d (project default
   and hardcoded table). Extension keyword matches from 4b are final and
   not subject to alias remapping by other extensions.
```

**Verification**:
- Step 4 in both task.md copies contains all five sub-steps (4a-4e)
- Precedence chain is: meta > extension keywords > default_task_type > hardcoded table > general, with alias remapping after 4c/4d
- jq patterns use `// {}` for safe fallback on missing `keyword_overrides`
- Both copies (live + core extension) are byte-identical

---

### Phase 2: Document keyword_overrides in extension-development.md [COMPLETED]

**Goal**: Add the `keyword_overrides` field to the manifest schema documentation so extension authors know how to use it.

**Tasks**:
- [x] Add `keyword_overrides` to the Manifest Fields table in extension-development.md *(completed)*
- [x] Add a new section documenting the `keyword_overrides` schema, semantics, and examples *(completed)*
- [x] Add a note about keyword conflict resolution (first-match-wins, glob ordering) *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/context/guides/extension-development.md` - Add keyword_overrides documentation

**Details**:

1. In the Manifest Fields table (line 75-86), add a new row:

```
| `keyword_overrides` | object | No | Keyword-to-task_type mappings for /task command detection (see below) |
```

2. After the "Manifest Fields" section and before "Merge Process", add a new section:

```markdown
## Keyword Overrides

Extensions can register keywords that influence task-type detection during `/task` creation.
When a user creates a task, the description is scanned for extension-registered keywords
before falling through to the hardcoded keyword table.

### Schema

```json
"keyword_overrides": {
  "<task_type>": {
    "aliases": ["<existing_type>", ...],
    "keywords": ["<word1>", "<word2>", ...]
  }
}
```

### Field Semantics

| Field | Type | Description |
|-------|------|-------------|
| `<task_type>` (key) | string | The task type to assign when a keyword matches |
| `aliases` | array of strings | Existing task types to remap. If the hardcoded table or project default would assign one of these types, remap to this extension's type instead |
| `keywords` | array of strings | New keywords. If any appears in the task description (case-insensitive, whole-word), assign this extension's type |

### Precedence

Extension keyword overrides sit in the middle of the detection chain:

1. **Meta keywords** (always win): "meta", "agent", "command", "skill" -> meta
2. **Extension keywords** (from `keyword_overrides.*.keywords`): first match wins
3. **Project default** (`default_task_type` in state.json)
4. **Hardcoded keyword table** (built into task.md)
5. **Fallback**: general

Alias remapping applies after steps 3 and 4: if the resolved type matches an
extension's `aliases` array, it is remapped to that extension's type.

### Example

```json
{
  "keyword_overrides": {
    "cslib": {
      "aliases": ["lean4"],
      "keywords": ["cslib", "bisimulation", "lts"]
    }
  }
}
```

This configuration:
- Assigns `cslib` type when "cslib", "bisimulation", or "lts" appears in the description
- Remaps any task that would have been `lean4` (from hardcoded table or project default) to `cslib`

### Conflict Resolution

When multiple extensions register the same keyword, the first match wins (determined by
filesystem glob ordering of `.claude/extensions/*/manifest.json`). Extensions should use
specific, non-overlapping keywords to avoid conflicts.

### Best Practices

- Use domain-specific keywords that are unlikely to appear in unrelated task descriptions
- Keep the `keywords` array focused (5-15 entries)
- Use `aliases` sparingly -- only when your extension genuinely supersedes another type
- Do not alias `meta` -- meta keywords are unconditional and cannot be overridden
```

**Verification**:
- `keyword_overrides` appears in the Manifest Fields table
- New "Keyword Overrides" section exists with Schema, Field Semantics, Precedence, Example, Conflict Resolution, and Best Practices subsections
- Example is realistic and matches the schema

---

### Phase 3: Update CLAUDE.md merge source documentation [COMPLETED]

**Goal**: Update the CLAUDE.md documentation to mention extension keyword_overrides in the relevant sections.

**Tasks**:
- [x] Update the `default_task_type` documentation in the CLAUDE.md merge source to mention extension keyword_overrides in the precedence chain *(completed)*
- [x] Add a note about keyword_overrides in the Extension Task Types section *(completed)*
- [x] Regenerate CLAUDE.md if needed (or note that the merge source is the canonical edit point) *(completed: updated live CLAUDE.md to match merge source; Lua loader will resync on next extension load/unload)*

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/core/merge-sources/claudemd.md` - Update precedence chain documentation in the `default_task_type` and Extension Task Types sections

**Details**:

1. Find the `default_task_type` documentation paragraph (contains "Precedence: meta keywords > `default_task_type` > keyword table > `general`") and update it to:

```
Precedence: meta keywords > extension `keyword_overrides` > `default_task_type` > keyword table > `general`.
```

2. In the Extension Task Types section, add a note:

```
Extensions can register `keyword_overrides` in their manifest.json to automatically detect
their task type from keywords in the task description during `/task` creation. See
`.claude/context/guides/extension-development.md` for the keyword_overrides schema.
```

3. Regenerate CLAUDE.md:
```bash
# The loader regenerates CLAUDE.md from merge sources; a manual trigger may be needed
# or the next extension load/unload will regenerate automatically
```

**Verification**:
- CLAUDE.md merge source contains updated precedence chain
- Extension Task Types section mentions keyword_overrides
- Generated CLAUDE.md reflects the changes (if regeneration is triggered)

## Testing & Validation

- [ ] Verify step 4 in `.claude/commands/task.md` contains all five sub-steps (4a through 4e)
- [ ] Verify `.claude/extensions/core/commands/task.md` is byte-identical to the live copy
- [ ] Verify `keyword_overrides` is documented in extension-development.md Manifest Fields table
- [ ] Verify the precedence chain in CLAUDE.md merge source reads: meta > extension keyword_overrides > default_task_type > keyword table > general
- [ ] Verify no existing extension manifest is modified (this task only adds the infrastructure)
- [ ] Verify jq patterns in task.md use `// {}` for safe fallback on manifests without `keyword_overrides`

## Artifacts & Outputs

- `specs/682_extension_keyword_overrides_task_command/plans/02_keyword-overrides-plan.md` (this file)
- `specs/682_extension_keyword_overrides_task_command/summaries/02_keyword-overrides-summary.md` (after implementation)
- Modified files:
  - `.claude/commands/task.md`
  - `.claude/extensions/core/commands/task.md`
  - `.claude/context/guides/extension-development.md`
  - `.claude/extensions/core/merge-sources/claudemd.md`

## Rollback/Contingency

All changes are to prose instruction files and documentation. Rollback is straightforward:
- Revert task.md step 4 to the three-bullet format (meta > default > keyword table > general)
- Remove the keyword_overrides section from extension-development.md
- Revert the precedence chain text in CLAUDE.md merge source
- `git checkout` on affected files restores pre-change state
