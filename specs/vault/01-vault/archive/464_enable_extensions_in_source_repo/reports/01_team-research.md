# Research Report: Task #464

**Task**: Enable extension loading in global source repository without sync leakage
**Date**: 2026-04-16
**Mode**: Team Research (4 teammates)

## Summary

The source repository (~/.config/nvim) serves a dual role as both the authoritative sync source for the core agent system and a consumer that should be able to use extensions. A self-loading guard currently prevents extension loading in this repo. Analysis shows that most leak vectors are already handled by existing protections, with only two real gaps requiring new code. The recommended approach is a targeted sync-time stripping fix (~20-30 lines) rather than architectural restructuring.

## Key Findings

### 1. Existing Protections Already Cover Most Artifact Types

The manifest-based blocklist (`aggregate_extension_artifacts()` in manifest.lua) reads all extension manifests and builds a set-based blocklist that filters extension-provided files during sync. This covers:

| Artifact Type | Protection | Status |
|---|---|---|
| Agents, skills, commands, rules, scripts | Manifest blocklist | **Safe** |
| Context directories (e.g., `project/neovim/`) | Prefix matching in blocklist | **Safe** |
| `context/index.json` | `CONTEXT_EXCLUDE_PATTERNS` excludes it from sync entirely | **Safe** |
| Data directories (`.memory/`) | Not in sync path (goes to project root) | **Safe** |
| **CLAUDE.md sections** | **No stripping mechanism exists** | **LEAKS** |
| **settings.json / settings.local.json** | **No blocklist for root_files** | **POTENTIAL LEAK** |

### 2. CLAUDE.md Section Injection Is the Primary Leak Vector

When an extension is loaded, it injects a `<!-- SECTION: extension_nvim -->...<!-- END_SECTION: extension_nvim -->` block into `.claude/CLAUDE.md`. The sync copies this file as a `root_file` from the source repo to target repos. The existing `preserve_sections()` / `restore_sections()` logic in sync.lua was designed for the *target* side (preserving a target repo's loaded extension sections across sync). It does **not** strip extension sections from the *source* content before copying.

The infrastructure to fix this already exists: `preserve_sections()` can extract section blocks from content. A `strip_extension_sections()` function performing the inverse operation would be straightforward.

### 3. Secondary Leak Vector: settings.json / settings.local.json

Extensions that declare `merge_targets.settings` merge MCP server configurations and other keys into settings files. These files are synced as `root_files` with no blocklist filtering. Currently, the nvim and memory extensions do **not** use settings merge targets, but other extensions (e.g., lean with its MCP server configuration) do. This vector needs coverage.

### 4. Critic Finding: `update_artifact_from_global()` Bypasses the Blocklist

Individual file updates via Ctrl-l (`update_artifact_from_global()`) copy files directly from the global path to the local path with **no blocklist filtering**. If extension artifacts exist in the source repo's `.claude/agents/` or `.claude/skills/`, they could be individually synced to target repos through this path. This is a real gap not covered by the batch sync protections.

### 5. Additional Gaps Identified

- **Unprotected sync categories**: `docs/`, `lib/`, `tests/`, `templates/`, `systemd/` receive no blocklist filtering. No current extension uses these, but future extensions could.
- **Hardcoded guard path**: The self-loading guard checks `vim.fn.expand("~/.config/nvim")` rather than using the configured `global_source_dir`, creating an inconsistency if the source path is non-standard.
- **No audit detection**: The post-sync audit system has no patterns configured to detect extension section markers in synced files.

### 6. "Core as Extension" Is Premature

The approach of restructuring the core agent system as a base extension was evaluated by Teammates B and D. Both conclude it is the correct long-term direction but practically infeasible now due to:
- Massive migration cost (all core files restructured)
- Circular architecture (extension loader lives outside `.claude/`)
- No practical gain over the targeted fix
- 6-12 month effort vs. days for the minimal approach

### 7. Symlink Approach Is Unnecessary Given Existing Blocklist

Teammate B proposed symlink-based loading (using the existing `skip_symlinks` parameter in `scan_directory_for_sync`). However, since the manifest blocklist already handles all file-copy artifacts, symlinks solve a problem that's already solved. They also add complexity (Claude Code symlink following unverified) and don't address the merged-content problem (CLAUDE.md sections, settings).

### 8. Roadmap Alignment Is Strong

This change is a prerequisite or accelerant for several roadmap items:
- **Extension hot-reload** (Phase 2): Requires loading in source repo to test
- **Manifest-driven README generation** (Phase 1): Authors need to verify generated content against live state
- **Extension slim standard enforcement** (Phase 1): Lint scripts easier to validate when extension is loaded
- **CI enforcement of doc-lint** (Phase 1): Needs local loading to validate load/unload cycle

## Synthesis

### Conflicts Resolved

| Conflict | Resolution |
|---|---|
| Symlinks (B) vs. strip-on-sync (A, D) | Strip-on-sync wins. Blocklist already handles file artifacts; symlinks add complexity for a solved problem. |
| index.json safety | **Safe** - Teammate A traced the exact code path showing it's in `CONTEXT_EXCLUDE_PATTERNS` and never synced. |
| Scope of fix (minimal vs. architectural) | Minimal fix (A, D) recommended. Core-as-extension is premature (B, D agree). |
| Guard: remove vs. relax | Relax to context-sensitive (D's recommendation). Remove the block but keep a log/notification when loading in source repo. |

### Gaps Identified

1. **No stripping mechanism exists** for extension sections in source CLAUDE.md during sync-out (all teammates agree this is new code needed)
2. **`update_artifact_from_global()`** needs blocklist or state-aware filtering (Teammate C, unique finding)
3. **Settings merge targets** need sync-time handling if any loaded extension uses them
4. **No audit patterns** for extension section markers in post-sync validation

### Recommendations

**Phase 1 (Core Fix)**:
1. Add `strip_extension_sections()` to sync.lua that removes `<!-- SECTION: extension_* -->` blocks from source CLAUDE.md content before copying to targets
2. Relax the self-loading guard in init.lua to allow loading with a notification (not an error)
3. Extend `update_artifact_from_global()` to apply the manifest blocklist before individual file copies

**Phase 2 (Hardening)**:
4. Add settings.json stripping: when syncing settings files, filter out keys that were merged by extensions (use `extensions.json` merged_sections tracking)
5. Fix the hardcoded `~/.config/nvim` path in the guard to use configured `global_source_dir`
6. Add extension section marker patterns to `.sync-exclude` for post-sync audit detection
7. Extend blocklist to cover currently-unprotected categories (docs, lib, tests, templates)

**Design Constraints** (preserve for future core-as-extension work):
- Do not change the manifest format
- Do not change how extensions.json tracks state
- Keep the sync layer's blocklist mechanism extensible

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Primary Approach | completed | high | Traced exact leak vectors; only 2 of 7 artifact types actually leak |
| B | Alternative Architectures | completed | medium-high | Evaluated 6 approaches; symlink + state-aware hybrid |
| C | Critic | completed | high | Found `update_artifact_from_global()` bypass and unprotected categories |
| D | Horizons | completed | high | Roadmap alignment; incremental vs. architectural trade-off |

## References

### Code Paths Traced
- `sync.lua:sync_files()` - CLAUDE.md section leak path (lines 258-269)
- `sync.lua:scan_all_artifacts()` - root_files include CLAUDE.md (lines 693-712)
- `manifest.lua:aggregate_extension_artifacts()` - blocklist builder (lines 233-261)
- `sync.lua:preserve_sections()` / `restore_sections()` - section handling infrastructure
- `sync.lua:update_artifact_from_global()` - individual file update (no blocklist)
- `init.lua:manager.load()` - self-loading guard (lines 212-230)
- `scan.lua:scan_directory_for_sync()` - `skip_symlinks` parameter (line 53)

### Teammate Reports
- `specs/464_enable_extensions_in_source_repo/reports/01_teammate-a-findings.md`
- `specs/464_enable_extensions_in_source_repo/reports/01_teammate-b-findings.md`
- `specs/464_enable_extensions_in_source_repo/reports/01_teammate-c-findings.md`
- `specs/464_enable_extensions_in_source_repo/reports/01_teammate-d-findings.md`
