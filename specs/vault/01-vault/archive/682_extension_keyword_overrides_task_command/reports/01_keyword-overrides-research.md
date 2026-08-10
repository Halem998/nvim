# Research Report: Task #682

**Task**: 682 - Add extension keyword_overrides support to /task command
**Started**: 2026-06-14T00:00:00Z
**Completed**: 2026-06-14T00:10:00Z
**Effort**: Small (1-2 hours implementation)
**Dependencies**: None
**Sources/Inputs**:
- `/home/benjamin/.config/nvim/.claude/commands/task.md`
- `/home/benjamin/.config/nvim/.claude/scripts/command-route-skill.sh`
- `/home/benjamin/.config/nvim/.claude/scripts/command-gate-in.sh`
- `/home/benjamin/.config/nvim/.claude/extensions/*/manifest.json` (all 15 extension manifests)
- `/home/benjamin/.config/nvim/.claude/context/guides/extension-development.md`
- `/home/benjamin/.config/nvim/.claude/extensions.json`
**Artifacts**: `specs/682_extension_keyword_overrides_task_command/reports/01_keyword-overrides-research.md`
**Standards**: report-format.md

---

## Executive Summary

- The keyword detection logic in `/task` step 4 is a **hardcoded table in the command prompt** (task.md, line 109-113), not a script
- No extension manifest currently has a `keyword_overrides` field; this is a net-new schema addition
- The `command-route-skill.sh` script shows the pattern for manifest scanning (jq over `extensions/*/manifest.json`), but keyword detection happens earlier — at task creation time in task.md, before any routing occurs
- Implementation requires: (1) a new `keyword_overrides` field in manifest.json schema, (2) a bash scan loop inserted into task.md step 4, (3) a documented precedence chain: meta keywords > extension overrides > `default_task_type` > hardcoded table > `general`

---

## Context & Scope

The task asks for extension-controlled task-type keyword detection at creation time. Currently, when `/task "Write a lean4 proof"` is invoked, the command assigns a `task_type` based on a hardcoded keyword table (step 4 in task.md). Extensions cannot influence this — they can only route tasks after the type is assigned. The feature adds a `keyword_overrides` field to manifest.json that lets extensions register their own keywords and type remapping aliases.

**Scope**: Changes touch only `task.md` (the /task command definition). No changes to routing scripts, state.json schema, or extension loader are required.

---

## Findings

### Codebase Patterns

#### The Keyword Detection Location

**File**: `/home/benjamin/.config/nvim/.claude/commands/task.md`
**Step**: Step 4 ("Detect language from keywords"), lines 109-113

The complete current implementation is:
```
4. **Detect language** from keywords:
   - "neovim", "plugin", "nvim", "lua" → neovim
   - "meta", "agent", "command", "skill" → meta
   - Otherwise → general
```

This is a prose instruction to Claude — not a shell script. The language detected here is stored as `task_type` in state.json and used later by routing commands (`/research`, `/plan`, `/implement`).

**Important context from CLAUDE.md**: The field is documented as `language` in task.md step 4 but stored in state.json as `task_type`. The two names refer to the same field. The CLAUDE.md `default_task_type` documentation establishes the current precedence:

```
meta keywords > default_task_type > keyword table > general
```

The proposed change inserts extension overrides into this chain:

```
meta keywords > extension keyword_overrides > default_task_type > keyword table > general
```

#### Extension Discovery Pattern

**File**: `/home/benjamin/.config/nvim/.claude/scripts/command-route-skill.sh` (lines 34-43)

The established pattern for scanning extension manifests:
```bash
for _manifest in .claude/extensions/*/manifest.json; do
  if [ -f "$_manifest" ]; then
    _ext_skill=$(jq -r --arg op "$_route_operation" --arg tt "$_route_task_type" \
      '.routing[$op][$tt] // empty' "$_manifest" 2>/dev/null)
    if [ -n "$_ext_skill" ]; then
      SKILL_NAME="$_ext_skill"
      break
    fi
  fi
done
```

This pattern (glob + jq per-manifest) should be mirrored in task.md's step 4 logic.

**Extension file path**: `.claude/extensions/*/manifest.json` — the glob used in command-route-skill.sh. The `extensions.json` registry uses absolute `source_dir` paths, so the glob is the correct portable approach.

#### Current Keyword Table Analysis

The hardcoded table currently contains only two type mappings:
- `neovim` type: keywords "neovim", "plugin", "nvim", "lua"
- `meta` type: keywords "meta", "agent", "command", "skill"
- Default: `general`

This table is intentionally minimal — most extension task types (lean4, latex, python, nix, formal) are NOT in the hardcoded table. Users must either know the exact task_type string or rely on `default_task_type`. This gap is the motivation for the feature.

#### Extension Manifest Schema (Current)

All 15 extension manifests were reviewed. The relevant top-level fields are:

```json
{
  "name": "string",
  "version": "semver",
  "description": "string",
  "task_type": "string",        // primary type this extension handles
  "dependencies": ["string"],
  "provides": {...},
  "routing": {                  // maps task_type -> skill per operation
    "research": {"task_type": "skill-name"},
    "plan": {"task_type": "skill-name"},
    "implement": {"task_type": "skill-name"}
  },
  "routing_hard": {...},        // optional hard-mode routing (lean extension only)
  "merge_targets": {...},
  "mcp_servers": {},
  "hooks": {}
}
```

**No extension currently has `keyword_overrides`**. This field does not exist in any manifest.

#### Loaded Extensions Registry

**File**: `/home/benjamin/.config/nvim/.claude/extensions.json`

Currently loaded extensions (status: active): `memory`, `core`, `nvim`, `nix`

The lean, formal, latex, python, and other extensions are defined in source directories but not currently loaded. The keyword scanning must work across all manifests in `.claude/extensions/*/manifest.json` (source directory), not just loaded extensions — OR only scan loaded extensions via `extensions.json`. The routing script uses the glob approach (all present manifests), which is the safer choice for task creation since loading state can change.

---

### Proposed Schema: `keyword_overrides`

The task description specifies this schema:

```json
"keyword_overrides": {
  "task_type": {
    "aliases": ["existing_type"],
    "keywords": ["word1", "word2"]
  }
}
```

**Field semantics**:
- `task_type` (the object key): The extension's type to assign when a keyword matches
- `aliases`: Array of existing task_type values. If the hardcoded table returns one of these types, remap to this extension's type. Example: `"aliases": ["general"]` means "if the hardcoded table would say 'general', claim it as my type instead"
- `keywords`: Array of new keyword strings. If any appears in the description, assign this extension's type (overrides the hardcoded table result)

**Example** for a hypothetical `lean` extension claiming lean-related keywords:
```json
"keyword_overrides": {
  "lean4": {
    "aliases": [],
    "keywords": ["lean4", "lean", "theorem", "proof", "mathlib", "lake"]
  }
}
```

**Example** for an extension that supersedes `general`:
```json
"keyword_overrides": {
  "python": {
    "aliases": ["general"],
    "keywords": ["python", "pytest", "pip", "django", "flask"]
  }
}
```

---

### Where to Insert in the Flow

Step 4 of task.md is currently a 3-bullet instruction. The new logic inserts between the meta keyword check and the hardcoded keyword table:

**New step 4 flow**:

```
4. **Detect task_type** from description keywords:

   4.1 **Meta keywords** (always take precedence):
       - "meta", "agent", "command", "skill" → meta

   4.2 **Extension keyword_overrides** (scan extension manifests):
       For each .claude/extensions/*/manifest.json:
         For each task_type key in keyword_overrides:
           - Check if any keyword in keyword_overrides[task_type].keywords
             appears in the description → assign that task_type, stop scanning
         After all keywords checked, apply aliases:
           - If tentative result from step 4.3 matches any alias → remap to
             this extension's task_type
       (First-match wins across extensions)

   4.3 **Hardcoded keyword table** (fallback if no extension match):
       - "neovim", "plugin", "nvim", "lua" → neovim
       - Otherwise → general

   4.4 **default_task_type override** (from state.json):
       - If state.json has non-null default_task_type, override the above result
         (except meta keywords which remain sticky)
```

**Note on alias evaluation order**: Aliases reference the hardcoded table result. The natural evaluation order is:
1. Check meta keywords → if match, done (type = meta)
2. Scan extension keywords → if any match, record as tentative extension_type
3. If no extension keyword matched, run hardcoded table → get tentative_type
4. Re-scan extension aliases → if tentative_type matches any alias, remap
5. Apply default_task_type if set

However, the task description says "aliases remap an existing keyword table result" — so aliases apply to the hardcoded table output, not to other extensions' keyword results. This means:
- Keyword matches in step 2 fire before alias evaluation
- Aliases in step 4 only remap step 3 (hardcoded table) results

---

### Implementation in task.md

Since task.md is a prose instruction file (not a shell script), the implementation is descriptive rather than literal bash. However, the planner should specify it clearly enough that Claude can execute the scan during task creation.

The scan instruction should reference `jq` over `.claude/extensions/*/manifest.json` with `.keyword_overrides // {}` to safely handle missing fields. It should be conditional on the file existing.

**Bash pseudocode** for the agent to follow:
```bash
# Scan for extension keyword matches
for manifest in .claude/extensions/*/manifest.json; do
  [ -f "$manifest" ] || continue
  # Check keywords
  matched_type=$(jq -r --arg desc "$description" '
    .keyword_overrides // {} | to_entries[] |
    select(.value.keywords[]? as $kw | $desc | ascii_downcase | contains($kw)) |
    .key' "$manifest" 2>/dev/null | head -1)
  [ -n "$matched_type" ] && { task_type="$matched_type"; break; }
done

# If no extension keyword matched, run hardcoded table, then check aliases
if [ -z "$task_type" ]; then
  # hardcoded table → tentative_type
  for manifest in .claude/extensions/*/manifest.json; do
    [ -f "$manifest" ] || continue
    aliased=$(jq -r --arg tt "$tentative_type" '
      .keyword_overrides // {} | to_entries[] |
      select(.value.aliases[]? == $tt) | .key' "$manifest" 2>/dev/null | head -1)
    [ -n "$aliased" ] && { task_type="$aliased"; break; }
  done
fi
```

**Important**: task.md uses prose instructions that Claude follows, so the implementation is a description of this logic, not literal bash embedded in the command.

---

## Decisions

- The feature belongs entirely in `task.md` (step 4) — no changes needed to routing scripts, state.json, or the extension loader
- The scan glob should be `.claude/extensions/*/manifest.json` (all present manifests, same as `command-route-skill.sh`), not filtered by `extensions.json` loaded state
- First-match-wins across extensions (deterministic, predictable)
- Aliases apply only to the hardcoded-table result, not to other extensions' keyword_overrides results
- The `keyword_overrides` field is optional (missing = `{}` = no effect); manifests without it are unaffected
- Meta keywords ("meta", "agent", "command", "skill") remain hardcoded in task.md and cannot be claimed by extension keyword_overrides

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Extension keyword conflicts (two extensions claim same keyword) | First-match-wins; recommend extensions use specific non-overlapping keywords |
| Performance: scanning all manifests on every `/task` invocation | Acceptable — few manifests (15), fast jq, only at task creation time |
| `keyword_overrides` field absent in existing manifests | Use `jq .keyword_overrides // {}` to safely return empty object |
| jq `contains()` doing substring matching, too broad | Use word-boundary checking or exact word list match in implementation |
| Alias creates circular remapping | Aliases only remap hardcoded table results; no extension-to-extension alias chains possible |
| task.md is prose, not script — scanning must be described accurately | Plan should specify exact jq patterns the agent should use |

---

## Context Extension Recommendations

None — this is a meta task modifying the agent system itself.

---

## Appendix

### Files Examined

| File | Lines | Purpose |
|------|-------|---------|
| `.claude/commands/task.md` | 546 | Task command definition — step 4 is the change target |
| `.claude/scripts/command-route-skill.sh` | 67 | Reference pattern for manifest scanning |
| `.claude/scripts/command-gate-in.sh` | 74 | Shows TASK_TYPE export flow |
| `.claude/extensions/nvim/manifest.json` | 58 | Typical extension manifest |
| `.claude/extensions/lean/manifest.json` | 89 | Shows routing_hard pattern |
| `.claude/extensions/core/manifest.json` | 186 | Core extension, routing_exempt |
| `.claude/extensions/formal/manifest.json` | 67 | Multi-subtype routing |
| `.claude/extensions/python/manifest.json` | 54 | Simple extension |
| `.claude/extensions/latex/manifest.json` | 56 | Simple extension |
| `.claude/extensions.json` | 580 | Loaded extension registry |
| `.claude/context/guides/extension-development.md` | 256 | Manifest schema reference |

### Key Insight: task.md is Prose, Not Shell

Unlike `command-route-skill.sh` (an actual bash script), `task.md` is a prompt instruction file that Claude reads and executes. The "implementation" here is editing the prose description of step 4 to instruct Claude how to scan manifests and apply keyword_overrides. The plan should be written accordingly — no new shell script is needed, only an update to the task.md instruction text.
