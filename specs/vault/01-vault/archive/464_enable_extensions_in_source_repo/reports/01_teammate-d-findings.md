# Teammate D Findings: Horizons Research
# Task 464: Enable Extension Loading in Global Source Repository

## Executive Summary

This task addresses a genuine architectural tension: the source repository
(~/.config/nvim) plays a dual role as both the *authoring environment* for
extensions and a *consumer* of those extensions. The current self-loading guard
resolves this tension by prohibiting extension use in the source repo entirely.
The right long-term solution is not to weaken the guard but to make it
context-sensitive -- distinguishing between *development use* (local, ephemeral,
legitimate) and *core sync contamination* (the actual risk the guard protects
against).

The sync system already solves half of this problem correctly. The
`aggregate_extension_artifacts()` blocklist in `manifest.lua` filters all
extension-provided artifacts from "Load Core Agent System" scans regardless of
what is currently loaded in the source repo. This means **the leak risk is
already mitigated by the sync layer**, and the self-loading guard is more
conservative than it needs to be.

---

## Key Findings

### 1. The Sync Layer Already Provides the Core Protection

The self-loading guard in `init.lua` (`manager.load()`, lines 212-229) blocks
loading when `project_dir == global_dir`. But `sync.lua` independently builds a
blocklist from `manifest.aggregate_extension_artifacts()` that filters every
extension-provided agent, skill, rule, command, context entry, and script from
the sync scan. This blocklist operates unconditionally -- it does not inspect
`extensions.json` to see what is loaded; it reads all manifests and excludes
everything they provide.

**Implication**: even if extensions are loaded in the source repo, "Load Core
Agent System" in other repos would not copy those artifacts. The guard is
defense-in-depth, not the primary line of defense.

### 2. The Guard Has One Legitimate Concern: Merge Target Contamination

The sync blocklist covers *file-copy* artifacts but has a gap: it does not strip
extension-injected sections from `CLAUDE.md` or extension-appended entries from
`context/index.json` when those files are synced. The `sync.lua` root_files sync
copies `.claude/CLAUDE.md` from the source repo directly. If an extension has
injected its section block into that file, the section block would be copied to
target repos -- where the extension is not installed and the agents it references
do not exist.

This is the real and non-trivial risk the guard is protecting against.

However, `sync.lua` already has `preserve_sections()` / `restore_sections()` and
`reinject_loaded_extensions()` logic designed to handle exactly this pattern
*in the other direction* (preserving locally-loaded extension sections after a
sync-in). The same mechanism could be inverted: a **strip-sections** pass during
sync-out from the global repo could remove extension-injected blocks before
writing to targets.

### 3. The Ideal Architecture Separates Source-Side and Target-Side Concerns

The cleanest long-term design has two distinct modes:

**Source-side (authoring) mode** -- what the nvim repo needs:
- Extensions can be loaded for development and testing
- `extensions.json` is written as usual (git-tracked, but marked as
  "development state")
- The CLAUDE.md and index.json merge targets are written locally
- Sync-out strips extension sections before copying to targets

**Target-side (consumer) mode** -- what all other repos use:
- Extensions are loaded by the user, tracked in `extensions.json`
- Sync-in preserves existing extension sections (current behavior)
- No authoring tools needed

The current design treats both modes identically. The fix should be to add a
source-aware strip pass to sync-out rather than preventing loading altogether.

### 4. Roadmap Alignment Is Strong

This change is a prerequisite or natural accelerant for several roadmap items:

| Roadmap Item | Relationship |
|---|---|
| Extension hot-reload (Phase 2) | Requires being able to *load* in the source repo to test reload behavior |
| Extension marketplace metadata | Loading locally enables testing marketplace workflows end-to-end |
| Manifest-driven README generation | Authors need to load extensions to verify generated content against live state |
| Extension slim standard enforcement | Lint scripts are easier to validate when the extension is actually loaded |
| CI enforcement of doc-lint | Needs local loading to validate the full load/unload cycle in CI |

None of these roadmap items are *blocked* by the current guard, but several are
made harder to develop and test because the authoring environment cannot consume
its own products.

### 5. Incremental vs. Architectural Approach

**Option A -- Minimal fix (recommended for now)**: Add a `source_mode` flag to
the extension manager that bypasses the guard but passes a `strip_on_sync = true`
signal. The sync layer strips extension sections from CLAUDE.md and extension
entries from index.json before copying them out. This is a 2-phase change
(loader + sync) with low risk and immediate value.

**Option B -- Core-as-extension restructuring**: Restructure the core agent
system as a "base" extension that other extensions declare as a dependency. This
is architecturally elegant and aligns with marketplace thinking but would require
substantial rework of the manifest format, loader, and sync system. It is a
6-12 month vision, not a near-term implementation.

**Option C -- Dual-state extensions.json**: Maintain two separate state files:
`extensions.json` (production, synced) and `extensions.dev.json` (development,
git-ignored). The loader reads both but only the production state is used by the
sync system. This is a middle path with moderate complexity.

The strategic recommendation is Option A now, with Option C as an enhancement
if the development-vs-production distinction becomes important across multiple
workflows.

### 6. The "Core as Extension" Framing Is Premature But Worth Designing Toward

The user's suggestion of making the core agent system itself an extension that
others depend on is the natural end state of the extension system's own design
principles. It would enable:

- **Versioned core**: Different repos could pin to different core versions
- **Extension marketplace**: Extensions declare `"core": ">=2.0.0"` as a
  dependency
- **Extension composition**: Extensions can safely override or extend core
  behavior by declaring explicit dependencies
- **Easier authoring**: The nvim repo becomes just another consumer of the core
  extension

However, this requires solving several non-trivial problems:
- Where does the "core" extension live? (It cannot live in `.claude/extensions/`
  without circular reference)
- How does the sync system bootstrap itself before the core is loaded?
- How do target repos discover the core extension source?

These are solvable but not urgent. The right approach is to **design the minimal
fix with this end-state in mind** -- specifically, avoid any decisions in the
Option A implementation that would make Option C/core-as-extension harder later.

---

## Strategic Recommendations

### Near-Term (this task)

1. **Lift the self-loading guard conditionally**, not unconditionally. Add a
   `source_repo = true` flag to the extension config or loader options that
   enables loading in the source repo with explicit acknowledgment of the risk.

2. **Add strip-on-sync to the sync layer**. When performing "Load Core Agent
   System" from the global dir, strip any `<!-- SECTION: extension_* -->` blocks
   from CLAUDE.md before copying to targets. Similarly, filter any extension-
   tracked index entries from `context/index.json` during sync. This closes the
   merge-target contamination gap and makes the guard truly redundant.

3. **Add a `dev` metadata field to extensions.json** to mark entries loaded
   in source/development mode. This prepares for future Option C without
   requiring it now.

4. **Do not change the manifest format** for this task. The existing manifest
   structure is sufficient; the change is purely in the loader and sync layer.

### Medium-Term (adjacent roadmap items)

5. **Tackle extension slim standard enforcement** alongside this work. Once
   extensions can be loaded in the source repo, the lint script can be tested
   end-to-end against a loaded state. This is a natural bundling opportunity.

6. **Revisit the source_mode flag as part of extension hot-reload work**. Hot-
   reload requires the source repo to be a first-class testing environment. The
   two features share infrastructure and should be designed together.

### Long-Term (6-12 months)

7. **Design toward core-as-extension**. When implementing the extension
   marketplace metadata (ROADMAP Phase 1), add a `core_version` field to each
   extension manifest. This establishes the semantic dependency link without
   requiring the full refactor.

8. **Consider extension composition semantics** when designing the marketplace.
   The `dependencies` array already supports this; what is missing is a
   versioning protocol. SemVer with `>=` constraints would be sufficient.

---

## Confidence Level: High

The analysis of the sync layer behavior is based on direct reading of
`sync.lua` (line-by-line) and `manifest.lua`'s `aggregate_extension_artifacts()`.
The conclusion that the blocklist already filters file-copy artifacts is
definitive. The gap in merge-target contamination (CLAUDE.md sections and
index.json entries) is identified from the same source reading -- the
`preserve_sections()` function handles the inbound direction only.

Strategic recommendations are based on established patterns in the codebase
(parameterized config, idempotent merge operations, guard flags already used
for `opts.force`) and the stated roadmap. The core-as-extension framing is
assessed as "correct direction, premature implementation" with high confidence.

---

## Files Referenced

- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/init.lua`
  -- Self-loading guard (lines 212-229), dependency resolution
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
  -- `aggregate_extension_artifacts()` blocklist, `preserve_sections()` / `restore_sections()`
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/manifest.lua`
  -- `aggregate_extension_artifacts()` implementation (lines 233-261)
- `/home/benjamin/.config/nvim/.claude/docs/architecture/extension-system.md`
  -- Load/unload process, merge target tracking
- `/home/benjamin/.config/nvim/specs/ROADMAP.md`
  -- Extension hot-reload (Phase 2), marketplace metadata, doc-lint CI (Phase 1)
