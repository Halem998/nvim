# Research Report: Task #168 (Supplement)

**Task**: 168 - Verify core agent system loading without extensions
**Started**: 2026-03-10T18:30:00Z
**Completed**: 2026-03-10T19:15:00Z
**Effort**: 0.5-1 hours
**Focus**: Extension loader injection verification after loading all extensions into Vision project
**Dependencies**: Research-001 (prior findings on broken index.json paths)
**Sources/Inputs**: Extension manifests, loader source code, target project artifacts
**Artifacts**: This report
**Standards**: report-format.md

## Executive Summary

After loading ALL extensions via `<leader>ac` and `<leader>ao` into `/home/benjamin/Projects/Logos/Vision/`, the extension loader successfully copies all file artifacts (agents, skills, commands, rules, context, scripts) with **zero missing files**. However, there are **5 distinct issues** in how merged/injected metadata is handled:

1. **CRITICAL: index.json has 203 broken paths (.claude) and 122 broken paths (.opencode)** -- caused by inconsistent path prefixes in source index-entries.json files AND the loader not normalizing paths during injection.
2. **BUG: Epidemiology .claude manifest uses wrong merge_target_key** (`opencode_md` instead of `claudemd`), preventing CLAUDE.md section injection.
3. **BUG: 4 index-entries.json files use bare arrays** instead of `{entries: [...]}` objects, causing silent injection failure due to the loader's `entries_data.entries` check.
4. **INCONSISTENCY: .claude and .opencode filetypes/web manifests differ** -- .claude has extra items (deck-agent, skill-deck, deck.md, skill-tag, tag.md) not in .opencode manifests.
5. **LOW: extensions.json tracks empty installed_files/installed_dirs** despite successful file copies.

## Context and Scope

This supplemental research examines the extension loading process itself, after the user loaded all 11 extensions into the Vision project using the Neovim extension loader keymaps (`<leader>ac` for Claude, `<leader>ao` for OpenCode). The focus is on verifying the fidelity of the injection process rather than the core system (covered in research-001).

## Findings

### 1. File Artifact Copying: PASS (100%)

All files declared in extension manifests were successfully copied to the target:

| Category | .claude Status | .opencode Status |
|----------|---------------|-----------------|
| Agents (27 files) | All present | All present |
| Skills (29 dirs) | All present | All present |
| Commands (7 files) | All present | All present |
| Rules (5 files) | All present | All present |
| Context (13 dirs, 177 files) | All present | All present |
| Scripts (2 files) | All present | All present |

The `loader.lua` file copy engine (`copy_simple_files`, `copy_skill_dirs`, `copy_context_dirs`, `copy_scripts`) works correctly with atomic rollback on failure via `pcall`.

### 2. index.json Path Corruption: CRITICAL

**Root Cause**: The index-entries.json files in extension source directories use **three different path prefix conventions**, and the `merge.lua:append_index_entries()` function copies paths verbatim without normalization.

**Path prefix categories found in .claude index-entries.json source files**:

| Extension | Path Prefix Used | Correct Prefix | Status |
|-----------|-----------------|----------------|--------|
| epidemiology | `project/` | `project/` | OK |
| formal | `.claude/extensions/formal/context/project/` | `project/` | BROKEN |
| latex | `context/project/` | `project/` | BROKEN |
| lean | `context/project/` | `project/` | BROKEN |
| nix | `.claude/extensions/nix/context/project/` | `project/` | BROKEN |
| nvim | `context/project/` | `project/` | BROKEN |
| python | `context/project/` | `project/` | BROKEN |
| typst | `context/project/` | `project/` | BROKEN |
| web | `.claude/extensions/web/context/project/` | `project/` | BROKEN |
| z3 | `context/project/` | `project/` | BROKEN |

**Path prefix categories found in .opencode index-entries.json source files**:

| Extension | Path Prefix Used | Correct Prefix | Status |
|-----------|-----------------|----------------|--------|
| epidemiology | `project/` | `project/` | OK |
| formal | `.opencode/extensions/formal/context/project/` | `project/` | BROKEN |
| latex | `context/project/` | `project/` | BROKEN |
| lean | `context/project/` | `project/` | BROKEN |
| nix | `.opencode/extensions/nix/context/project/` | `project/` | BROKEN |
| nvim | `context/project/` | `project/` | BROKEN |
| python | `context/project/` | `project/` | BROKEN |
| typst | `context/project/` | `project/` | BROKEN |
| web | `.opencode/extensions/web/context/project/` | `project/` | BROKEN (also bare array) |
| z3 | `context/project/` | `project/` | BROKEN |

**Impact**: 203 of 223 entries in .claude/context/index.json and 122 of 142 entries in .opencode/context/index.json are broken. Agents using `jq` queries against index.json for context discovery will fail to find any extension context files.

**Fix locations**:
1. **Source fix**: Normalize paths in all index-entries.json files to use `project/` prefix (correct for resolution from the context/ directory).
2. **Loader fix**: Add path normalization in `merge.lua:append_index_entries()` to strip incorrect prefixes before appending.

### 3. Bare Array index-entries.json: BUG

Four index-entries.json files use a bare JSON array `[{...}, {...}]` instead of the expected `{"entries": [{...}, {...}]}` object format:

| System | Extension | Structure | Effect |
|--------|-----------|-----------|--------|
| .claude | filetypes | Bare array (8 entries) | Silent skip -- entries NOT injected |
| .opencode | filetypes | Bare array | Silent skip |
| .opencode | nix | Bare array (11 entries) | Silent skip |
| .opencode | web | Bare array | Silent skip |

**Root cause**: The loader checks `entries_data.entries` (line 98 of init.lua), which returns `nil` for bare arrays, so the entire block is silently skipped. No error is reported.

**Impact**: Context entries for these extensions are not added to the target index.json. For .opencode, nix and web entries are missing entirely (since their index-entries.json are bare arrays).

**Fix**: Either:
- (a) Wrap bare arrays in `{"entries": [...]}` in the source files, or
- (b) Add fallback handling in the loader: `local entries = entries_data.entries or (vim.isarray(entries_data) and entries_data) or nil`

### 4. Epidemiology .claude Manifest: Wrong merge_target_key

The `.claude/extensions/epidemiology/manifest.json` uses `opencode_md` as its merge target key instead of `claudemd`:

```json
"merge_targets": {
  "opencode_md": {
    "source": "EXTENSION.md",
    "target": ".claude/OPENCODE.md",
    "section_id": "extension_oc_epidemiology"
  }
}
```

**Impact**: When loaded via the Claude extension system (`merge_target_key = "claudemd"`), the CLAUDE.md section injection is skipped. The epidemiology extension section is **NOT present** in the target CLAUDE.md. This is confirmed by the absence of `<!-- SECTION: extension_epidemiology -->` markers.

The .opencode manifest is correct (uses `opencode_md` which matches OpenCode's `merge_target_key`).

**Fix**: Change the .claude epidemiology manifest to use `claudemd`:
```json
"merge_targets": {
  "claudemd": {
    "source": "EXTENSION.md",
    "target": ".claude/CLAUDE.md",
    "section_id": "extension_epidemiology"
  }
}
```

### 5. Manifest Parity Gaps Between .claude and .opencode

The `.claude` filetypes manifest declares 5 agents, 4 skills, and 4 commands, while `.opencode` declares 4 agents, 3 skills, and 3 commands:

| Item | In .claude | In .opencode |
|------|-----------|-------------|
| deck-agent.md | Yes | No |
| skill-deck | Yes | No |
| deck.md (command) | Yes | No |
| skill-tag (web ext) | Yes | No |
| tag.md (web ext cmd) | Yes | No |

However, the actual target `.opencode/` directory contains these files anyway (likely from a prior manual copy or from a different loading mechanism). The manifests should be synchronized to accurately reflect what should be loaded.

### 6. CLAUDE.md/OPENCODE.md Section Injection: MOSTLY PASS

All 10 extensions (excluding epidemiology for .claude) have their sections correctly injected with proper `<!-- SECTION: ... -->` and `<!-- END_SECTION: ... -->` markers:

- **CLAUDE.md**: 10 of 11 sections present (missing: epidemiology due to bug #4)
- **OPENCODE.md**: 11 of 11 sections present

The `merge.lua:inject_section()` function handles idempotent updates correctly (re-running does not create duplicates).

### 7. Settings Merge: PASS

MCP server configurations were correctly merged into both settings.local.json files:
- `lean-lsp` (from lean extension)
- `mcp-nixos` (from nix extension)
- `rmcp` (from epidemiology extension)

The `merge.lua:merge_settings()` deep merge with deduplication works correctly.

### 8. extensions.json State Tracking: MINOR ISSUE

The extensions.json tracking files show `installed_files: []` and `installed_dirs: []` for all extensions despite successful file copies. This appears to be a state recording issue -- the `state_mod.mark_loaded()` call receives the file lists, but they may not be properly serialized.

**Impact**: Low. The unload function uses these lists to remove files, so unloading may not clean up properly. However, the merge tracking (merged_sections) works correctly for reverting CLAUDE.md/OPENCODE.md/settings changes.

## Extension Loader Architecture Analysis

### Loader Code Flow (init.lua)

```
manager.load(extension_name)
  |
  +-- manifest_mod.get_extension() -- Find extension source
  +-- state_mod.is_loaded() -- Check idempotency
  +-- loader_mod.check_conflicts() -- Pre-flight conflict check
  +-- pcall(function()
  |     +-- loader_mod.copy_simple_files("agents") -- OK
  |     +-- loader_mod.copy_simple_files("commands") -- OK
  |     +-- loader_mod.copy_simple_files("rules") -- OK
  |     +-- loader_mod.copy_skill_dirs() -- OK
  |     +-- loader_mod.copy_context_dirs() -- OK
  |     +-- loader_mod.copy_scripts() -- OK
  |     +-- process_merge_targets()
  |           +-- merge_mod.inject_section() -- OK (except epidemiology bug)
  |           +-- merge_mod.merge_settings() -- OK
  |           +-- merge_mod.append_index_entries() -- BROKEN (path prefixes)
  |     end)
  +-- state_mod.mark_loaded() -- State tracking (empty files issue)
```

### Key Gap: No Path Normalization

The `merge.lua:append_index_entries()` function (lines 332-371) blindly appends entries from the source index-entries.json without any path validation or normalization. It only deduplicates by exact path match.

**Recommended fix**: Add a normalization step before appending:

```lua
-- Normalize path: strip known bad prefixes
local function normalize_index_path(path, config)
  -- Strip .claude/extensions/*/context/ prefix
  path = path:gsub("^%.claude/extensions/[^/]+/context/", "")
  path = path:gsub("^%.opencode/extensions/[^/]+/context/", "")
  -- Strip bare context/ prefix
  path = path:gsub("^context/", "")
  -- Strip .claude/context/ prefix
  path = path:gsub("^%.claude/context/", "")
  path = path:gsub("^%.opencode/context/", "")
  return path
end
```

## Decisions

1. All 5 issues have clear, localized fixes.
2. The file copy engine is reliable -- issues are all in metadata/merge operations.
3. Source index-entries.json files should be normalized (fix once at source), AND the loader should add defensive normalization (belt and suspenders).

## Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Broken index.json prevents agent context discovery | CRITICAL | Fix source files + add loader normalization |
| Bare array index-entries.json silently skipped | HIGH | Add fallback handling in loader |
| Epidemiology missing from CLAUDE.md | MEDIUM | Fix manifest merge_target_key |
| Manifest parity gaps | LOW | Sync .claude/.opencode manifests |
| Empty installed_files in extensions.json | LOW | Debug state serialization |

## Recommendations

### Priority 1: Fix Source index-entries.json Path Prefixes

For all 11 extensions in both `.claude/extensions/` and `.opencode/extensions/`:
- Normalize all `path` values to use `project/` prefix (no leading `.claude/`, `context/`, or extension path)
- Validate: `project/{domain}/...` is the only valid prefix for extension context entries

Script approach:
```bash
for f in .claude/extensions/*/index-entries.json .opencode/extensions/*/index-entries.json; do
  jq '(.entries // .)[] |= (.path |= gsub("^\\.claude/extensions/[^/]+/context/"; "") | gsub("^\\.opencode/extensions/[^/]+/context/"; "") | gsub("^context/"; ""))' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
```

### Priority 2: Fix Bare Array index-entries.json

Wrap the 4 bare-array files in `{"entries": [...]}`:
- `.claude/extensions/filetypes/index-entries.json`
- `.opencode/extensions/filetypes/index-entries.json`
- `.opencode/extensions/nix/index-entries.json`
- `.opencode/extensions/web/index-entries.json`

### Priority 3: Fix Epidemiology .claude Manifest

Change `.claude/extensions/epidemiology/manifest.json`:
- Replace `"opencode_md"` with `"claudemd"` in merge_targets
- Update `section_id` from `"extension_oc_epidemiology"` to `"extension_epidemiology"`
- Update `target` from `".claude/OPENCODE.md"` to `".claude/CLAUDE.md"`

### Priority 4: Add Loader Path Normalization

In `merge.lua:append_index_entries()`, add a normalization pass on entry paths before appending. This provides defense-in-depth even if source files have inconsistent paths.

### Priority 5: Sync Manifest Parity

Add missing items to `.opencode` manifests:
- filetypes: Add `deck-agent.md`, `skill-deck`, `deck.md`
- web: Add `skill-tag`, `tag.md`

### Priority 6: Fix extensions.json State Tracking

Debug why `installed_files` and `installed_dirs` arrays are empty in the state file despite successful copies. Check `state_mod.mark_loaded()` serialization.

## Appendix

### Verification Methodology

1. Read all 11 extension manifests from both .claude and .opencode source directories
2. For each `provides` category, checked file/directory existence in target project
3. Validated index.json by testing each `path` entry for file existence relative to `context/` directory
4. Compared path prefixes against the expected `project/...` convention
5. Reviewed loader source code (init.lua, merge.lua, loader.lua, config.lua) for logic gaps
6. Checked CLAUDE.md/OPENCODE.md for section markers
7. Verified settings.local.json MCP server entries

### File Counts

| Component | .claude Source | .claude Target | .opencode Source | .opencode Target |
|-----------|--------------|----------------|-----------------|-----------------|
| Extensions | 11 | N/A (merged) | 11 | N/A (merged) |
| Agents | 27 ext | 27 present | 26 ext manifest | 26+ present |
| Skills | 29 ext | 29 present | 27 ext manifest | 27+ present |
| Commands | 7 ext | 7 present | 5 ext manifest | 5+ present |
| Rules | 5 ext | 5 present | 5 ext | 5 present |
| index.json entries | 223 total | 20 OK / 203 broken | 142 total | 20 OK / 122 broken |
