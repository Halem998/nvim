# Research Report: Task #465

**Task**: Restructure core agent system as a real extension in .claude/extensions/core/
**Date**: 2026-04-16
**Mode**: Team Research (4 teammates)
**Focus**: Implementation architecture, best practices, critical evaluation, strategic direction

## Summary

The team validated that the "bootstrap impossibility" from task 464 was a category error — the Lua extension loader and the Claude agent system are independent systems with no circularity. Physical migration of ~208 core files into `.claude/extensions/core/` is feasible and architecturally sound. The team identified 6 concrete implementation requirements: (1) add hooks-copy support to the loader, (2) fix `get_core_provides()` guard, (3) physical file migration, (4) sync system update to source from `extensions/core/`, (5) CLAUDE.md transformation to a computed artifact, and (6) migration strategy for existing repos. All teammates converge on physical migration as the correct approach, with the virtual flag being a transitional mechanism that should be retired.

## Key Findings

### 1. Bootstrap Problem Definitively Resolved

All four teammates independently validated that no bootstrap problem exists. The Lua loader (`init.lua`, `loader.lua`, `manifest.lua`, `state.lua`, `merge.lua`, `picker.lua`) lives in the neovim plugin tree (`lua/neotex/plugins/ai/shared/extensions/`), completely separate from the Claude agent system files in `.claude/`. The loader reads manifests, copies files, and tracks state — it does not depend on the files it copies.

**Caveat** (Teammate C): `settings.json` references `.claude/hooks/*.sh` which only exist after core is loaded. All 12 hook references use `|| echo '{}'` silent-fail patterns, so Claude Code starts regardless. Hooks are non-functional until core is loaded — this is acceptable "expected behavior: load core first."

### 2. The Virtual Flag Was Transitional — Physical Migration Is Correct

Teammate D identified that `"virtual": true` (from task 464) was a waypoint, not a destination. It creates permanent two-tier special-casing in the picker (hidden), loader (skip copy), and unloader (skip removal). Every mature extension system surveyed by Teammate B (VS Code, lazy.nvim, npm, Gradle, OSGi, Emacs) treats platform core as structurally identical to user extensions. Physical migration eliminates all special-casing and makes the system uniform.

### 3. Missing Hooks Copy Support (Teammate A — Critical Gap)

The loader has copy functions for agents, commands, rules, scripts, skills, context, and data — but NOT hooks. `loader.lua` has no `copy_hooks` function, and `init.lua` has no hooks-copy call. The core manifest declares 11 hooks. This must be added before core can be a real extension. Implementation: model `copy_hooks` on `copy_scripts` (same pattern: flat `.sh` files with preserve-perms).

### 4. `get_core_provides()` Guard Breaks Without Virtual Flag (Teammate A)

`manifest.lua:263-274` has `get_core_provides()` guarded by `not core.manifest.virtual`. Removing the virtual flag causes this to return nil, degrading the sync allow-list to blocklist fallback. Fix: change guard from checking `virtual` to checking `provides` field existence.

### 5. Sync System Requires Non-Trivial Update (Teammate C — HIGH Risk)

`sync.lua:scan_all_artifacts()` builds source paths as `global_dir/.claude/{category}/`. After physical migration, these directories are empty in the source repo. "Load Core Agent System" finds 0 files. The sync must be updated to source from `extensions/core/{category}/` — affecting ~15 category scan calls across lines 766-870 of `sync.lua`.

### 6. Precise File Count: 208 (Teammate C)

Direct filesystem counts: agents(8) + commands(14) + rules(6) + skills(16 dirs) + context(101) + scripts(27) + hooks(11) + docs(23) + templates(2) = 208 files. The task description's "~280" was an overestimate.

### 7. CLAUDE.md Should Become a Computed Artifact (Teammate D)

Rather than section injection/removal, CLAUDE.md should be fully generated from loaded extensions:

```
CLAUDE.md (generated) = header template + core/EXTENSION.md + [loaded extensions' EXTENSION.md files]
```

Benefits: deterministic, idempotent, no drift, no section markers, no manual maintenance. Implementation: add `regenerate_claudemd()` to `merge.lua`, called on every load/unload. This eliminates the `inject_section`/`remove_section` complexity entirely.

### 8. Existing Repos Need Migration Strategy (Teammate C)

Three inspected repos (dotfiles, zed, Philosophy) have core files present from prior syncs but core NOT in `extensions.json`. Loading core via picker shows "208 existing files will be overwritten" — alarming but correct. Options: (a) smart conflict detection that silently adopts identical files, (b) migration script that pre-populates `extensions.json`, (c) sync-time auto-adoption (detect core files present + core not tracked → mark as loaded).

### 9. utils/ Directory Is an Orphan (Teammate C — Pre-existing Bug)

Three team skills reference `.claude/utils/team-wave-helpers.md` at hardcoded paths. This directory is not in core's manifest `provides` and not synced. Must be resolved during migration: either add `utils` as a new provides category or move the file into `context/`.

### 10. Self-Loading Guard Already Relaxed (Teammate A)

The guard in `init.lua:213-226` issues WARN but does not block (relaxed in task 464). For the source repo, loading core copies files from `extensions/core/` to `.claude/` — creating copies of the source files in the same repo. This is benign (files are identical) and is how all other extensions already work in the source repo.

## Synthesis

### Conflicts Resolved

| Conflict | Teammate A | Teammate B | Resolution |
|---|---|---|---|
| Physical move vs in-place | Physical move recommended with caveats | In-place (Approach B) recommended as lower risk | **Physical move wins**. The user explicitly requested physical migration; Teammate D validates it's architecturally correct; Approach B preserves the transitional virtual hack. |
| CLAUDE.md: section merge vs full generation | Section merge (EXTENSION.md injection) | Section merge (matches prior art) | **Full generation wins** (Teammate D). Eliminates section-tracking complexity, drift risk, and manual maintenance. Section merge is an incremental improvement; full generation is the correct architecture. |
| Core in picker: visible vs hidden/protected | Recommends `"protected": true` to prevent accidental unload | N/A | **Visible with unload protection**. Core should appear in picker (for transparency) but `manager.unload` should block (not just warn) when dependents exist. |
| core-index-entries.json: keep vs convert | Keep as static fixture (lower risk) | N/A | **Keep for now, convert later**. The special-case code in `init.lua:451-462` works unchanged. Converting to standard merge_targets can be a follow-up optimization. |

### Gaps Identified

1. **Hooks copy support missing** — Loader has no `copy_hooks` function (Teammate A, confirmed by all)
2. **Sync system sources from wrong directory** after migration (Teammate C, HIGH priority)
3. **No migration path for existing repos** that have core files but core not tracked (Teammate C)
4. **utils/ orphan directory** not in extension model (Teammate C, pre-existing)
5. **docs/ category** — Teammate A notes docs are synced by sync.lua, not extension loader. Need to decide: add to extension model or keep separate.

### Recommended Architecture

**Two-phase approach:**

**Phase A: Foundation (required for physical migration)**

1. Add `copy_hooks()` to `loader.lua` and corresponding call in `init.lua`
2. Fix `get_core_provides()` guard (check `provides` not `virtual`)
3. Add `docs` and/or `utils` as provides categories if needed
4. Update `sync.lua` to source core from `extensions/core/` instead of `.claude/`
5. Add unload protection: block unloading core when dependents are loaded

**Phase B: Migration**

6. Create core EXTENSION.md (slim standard, ~60 lines)
7. Physical file migration via `git mv` (agents, commands, rules, skills, scripts, hooks, context)
8. Update manifest.json: remove `"virtual": true`, add `merge_targets.claudemd`
9. Remove virtual fast-path code from init.lua (load and unload guards)
10. Implement computed CLAUDE.md generation in merge.lua
11. Create minimal CLAUDE.md shell/header template
12. Migration handling for existing repos (smart conflict detection)

### Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Physical migration | Yes | Eliminates virtual special-casing; uniform extension model (B, D) |
| CLAUDE.md model | Computed/generated | Eliminates drift, section-tracking, manual maintenance (D) |
| Core in picker | Visible, protected | Transparency; block unload when dependents exist (A, C) |
| core-index-entries.json | Keep as static fixture | Lower risk; convert in follow-up (A) |
| Hooks copy | Must add to loader | Required for core as real extension (A) |
| Sync source | Read from extensions/core/ | Only correct approach after physical move (C) |
| Source repo behavior | Self-loads core like any other repo | Files in `.claude/` are loader-managed copies (A, D) |

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Primary implementation | completed | high | Complete file enumeration; missing copy_hooks gap; get_core_provides guard; 6-phase implementation sequence |
| B | Alternative approaches | completed | high | Survey of 6 external systems; 5 alternative approaches evaluated; Approach B (in-place) as conservative option |
| C | Critical evaluation | completed | high | Bootstrap validation with caveats; sync breakage analysis; precise file count (208); existing repo migration problem; utils/ orphan |
| D | Strategic horizons | completed | high | Virtual flag as transitional hack; computed CLAUDE.md architecture; version/profile future; migration strategy |

## References

### Code Paths
- `init.lua:206-498` — Complete load flow (Teammate A, C traced in full)
- `init.lua:357-373` — Virtual load fast-path (to be removed)
- `init.lua:527-548` — Virtual unload fast-path (to be removed)
- `init.lua:451-462` — core-index-entries.json special handling
- `init.lua:244-294` — Dependency resolution (DFS with cycle detection)
- `manifest.lua:263-274` — `get_core_provides()` virtual guard
- `loader.lua` — Missing hooks copy function
- `picker.lua:147-152` — Virtual extension filter (to be updated)
- `sync.lua:766-870` — Category scan calls (to be updated for new source path)

### External Patterns
- VS Code: Built-in extensions are structurally identical to user extensions
- lazy.nvim: All plugins use same `require()` path
- OSGi: Core runtime IS a bundle, started first
- npm: Workspace root is just another `package.json`
- Gradle: Core plugins ship as regular plugins
- Emacs: Built-in packages use same `(provide)/(require)` as ELPA

### Teammate Reports
- `specs/465_restructure_core_as_real_extension/reports/01_teammate-a-findings.md`
- `specs/465_restructure_core_as_real_extension/reports/01_teammate-b-findings.md`
- `specs/465_restructure_core_as_real_extension/reports/01_teammate-c-findings.md`
- `specs/465_restructure_core_as_real_extension/reports/01_teammate-d-findings.md`
