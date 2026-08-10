# Teammate D Findings: Horizons Research
# Task 465: Restructure Core Agent System as a Real Extension

**Focus**: Strategic direction, long-term alignment, and creative improvements
**Date**: 2026-04-16
**Predecessor context**: Task 464 completed the virtual core manifest and sync fixes. This task
asks whether we should go further: physically move core files into `.claude/extensions/core/`
so it becomes a real, loadable extension like any other.

---

## Key Findings

### 1. The Lua/Markdown Separation Eliminates the Bootstrap Problem

Task 464's Teammate C identified a "bootstrap impossibility." That finding applied to a naive
reading where the Lua extension loader *itself* would somehow need to be loaded by core. The
task description correctly resolves this: the Lua extension infrastructure
(loader.lua, manifest.lua, state.lua, merge.lua, picker.lua) lives in the Neovim plugin tree,
completely separate from the Claude agent system files. There is no circularity.

The real question is simpler: can the Lua loader load core from `extensions/core/` before any
other extension needs it? The answer is yes, trivially — the loader already handles `"virtual"`
extensions (task 464), and auto-loading dependencies already works. Core just becomes a
non-virtual extension that gets auto-loaded on every picker invocation (or lazily on first need).

**Confidence: High.** The implementation path is clear once the conceptual confusion is resolved.

### 2. The "virtual" Flag Was a Transitional Hack, Not a Final Architecture

The virtual core manifest (task 464) was the right minimal fix for its goal: enable extension
loading in the source repo without moving 175+ files. But "virtual" means "we're pretending
this is an extension without actually treating it like one." It creates a permanent two-tier
system: core is special-cased in the picker (hidden), in the loader (skip file copy), and in
the unloader (skip file removal). This special-casing will accumulate technical debt.

A real extension eliminates all special-casing. The `"virtual": true` flag in manifest.json
and all the guard logic in init.lua (`if ext_manifest.virtual then ... end`) become dead code
that can be removed. The system becomes uniform.

**The current state is a waypoint, not a destination.**

### 3. Physical Migration Enables a CLAUDE.md Architecture Transformation

Currently, CLAUDE.md is a manually maintained file with sections injected by extensions. It
is the *primary context document* loaded every session. Moving core into extensions/core/ enables
a fundamental rethink:

**Current model**: CLAUDE.md is a static document with extension sections merged in dynamically.
**Future model**: CLAUDE.md is a *computed artifact* assembled entirely from loaded extensions.

The minimal "shell" CLAUDE.md would contain only:
1. A preamble explaining this file is auto-generated
2. A reference to the bootstrap/loader documentation
3. Nothing else — all content comes from extension EXTENSION.md files

This is strictly better because:
- The document is always correct (no drift between installed extensions and CLAUDE.md content)
- Adding or removing an extension updates CLAUDE.md automatically
- The "routing table" in CLAUDE.md reflects exactly what is loaded
- No manual section management needed

**This is only achievable if core itself has an EXTENSION.md.** That requires physical migration.

### 4. Version Compatibility Checking Becomes Possible

Once core is a real extension with a real version (not `"version": "1.0.0"` on a virtual
placeholder), the extension system can enforce compatibility:

```json
{
  "name": "nvim",
  "version": "2.3.0",
  "dependencies": [
    { "name": "core", "min_version": "3.0.0", "max_version": "4.0.0" }
  ]
}
```

This is currently impossible because core has no meaningful version — it is always "whatever
is in `.claude/`." With a real extension, core versions semantically (patch for bug fixes,
minor for new skills/agents, major for breaking changes to routing or state schema).

Extensions can then detect incompatibility at load time rather than silently misbehaving.

### 5. Profile-Based Extension Sets Become Practical

With core as a loadable extension (even if auto-loaded), the system can support profiles:

```json
// .claude/profiles/writing.json
{
  "name": "writing",
  "description": "LaTeX, Typst, and bibliography tools",
  "extensions": ["core", "latex", "typst", "filetypes"]
}

// .claude/profiles/dev.json
{
  "name": "dev",
  "description": "Python, Nix, web development",
  "extensions": ["core", "python", "nix", "web"]
}
```

Profile-based loading has two benefits:
- **Reduced context window usage**: Only load extensions relevant to current work
- **Auditability**: The profile declares exactly what is active

This is only meaningful if core is in the extension system like other extensions. Otherwise
"core is always loaded" remains a hidden assumption outside the profile model.

### 6. Extension Marketplace Patterns Are Unlocked

The roadmap already mentions `marketplace.json` metadata per extension. With core as a real
extension, the full marketplace model works:

- Core has a canonical source URL, license, and version history
- Third-party extensions can declare `"dependencies": ["core@^3.0"]` and know what they get
- A hypothetical registry can check compatibility matrices
- The "fork core and add custom agents" workflow becomes a first-class pattern

Without core in the extension model, a marketplace would always have an asterisk: "* core is
special, it comes with the system, extensions can't really depend on a specific version of it."

---

## Strategic Improvements

Prioritized by impact/effort ratio (high impact first):

### Tier 1: Enables Everything Else (Include in this task)

**A. Physical file migration** (effort: high, impact: critical)
Move all `.claude/{agents,commands,skills,rules,context,scripts,hooks}/` files into
`.claude/extensions/core/`. Update all cross-references (scripts use relative paths,
context files use @-references). This is the core deliverable of this task.

**B. Core EXTENSION.md creation** (effort: low, impact: high)
Write a proper EXTENSION.md for core that documents all routing, agents, and context pointers.
This is what gets merged into CLAUDE.md when core loads. It should be lean (< 60 lines,
following the slim standard) because it forms the permanent base of every session's CLAUDE.md.

**C. Remove virtual flag machinery** (effort: low, impact: medium)
Delete the `if ext_manifest.virtual then` blocks in init.lua, the `"virtual"` field from
manifest.lua's type definitions, and the `get_core_provides()` allow-list builder. The allow-list
sync can be computed directly from core's real manifest.

### Tier 2: Achievable Alongside Migration (Include in this task)

**D. Computed CLAUDE.md architecture** (effort: medium, impact: high)
Rather than injecting/removing sections from a static file, generate CLAUDE.md entirely from
loaded extensions. Requires:
- A generator function in merge.lua: `generate_claudemd(loaded_extensions)`
- A "header template" file (the non-extension preamble)
- Calling the generator on every load/unload

The generated CLAUDE.md would be deterministic and idempotent. This simplifies load/unload
logic and eliminates section-tracking complexity.

**E. Semantic versioning for core** (effort: low, impact: medium)
Establish a version-bumping convention for core: patch for content fixes, minor for new
agents/skills, major for routing schema changes. Record the current state as `3.0.0` (matching
the README's "Version 3.0" marker). Document the convention in `.claude/docs/`.

**F. check-extension-docs.sh update** (effort: low, impact: low)
The doc-lint script currently reports expected failures for the virtual core extension. Once
core is real, it should pass the standard checks. Remove virtual-extension exemptions.

### Tier 3: Defer to Follow-Up Tasks

**G. Profile-based extension sets** (effort: medium, impact: medium)
Profiles are useful but not blocked on this task. Implement as a separate `/profile` command
after migration stabilizes.

**H. Version compatibility enforcement** (effort: medium, impact: medium)
Min/max version checking in dependencies requires defining the semver contract for core. Defer
until core has been through at least one major version bump post-migration.

**I. Extension marketplace metadata** (effort: low per extension, impact: low now)
Add `marketplace.json` to each extension as a ROADMAP item. Not blocked on core migration but
made more meaningful by it.

**J. Lazy loading of optional dependencies** (effort: high, impact: low now)
The current dependency system requires all dependencies. Optional/soft deps (load if available,
skip if not) require changes to the resolution algorithm. Defer.

**K. Dependency conflict detection UI** (effort: high, impact: low now)
Version conflict visualization in the picker requires the version checking infrastructure (H)
first. Defer.

---

## CLAUDE.md Architecture: Recommended Approach

### Current Architecture (Problematic)

```
CLAUDE.md (static, 400 lines)
├── Core content (manually maintained)
├── <!-- SECTION: extension_nvim --> (injected on load)
│   [nvim EXTENSION.md content]
│   <!-- END SECTION: extension_nvim -->
└── <!-- SECTION: extension_memory --> (injected on load)
    [memory EXTENSION.md content]
    <!-- END SECTION: extension_memory -->
```

Problems:
- Sections can desync from installed state
- Section injection/removal is stateful and error-prone
- Core content is not versioned or auditable as part of the extension model
- CLAUDE.md "drift" is a real concern (the ROADMAP notes this issue)

### Recommended Architecture (Generated)

```
CLAUDE.md (generated, deterministic)
= core/EXTENSION.md (always)
+ [extension A EXTENSION.md, if loaded]
+ [extension B EXTENSION.md, if loaded]
+ ...
```

Implementation:
1. `merge.lua` gains `regenerate_claudemd(project_dir, config)` function
2. Called on every `load()` and `unload()` operation
3. Output is written to `.claude/CLAUDE.md`
4. Source of truth is `extensions.json` (which extensions are loaded)
5. No section markers needed — entire file is regenerated
6. A "shell" header can be prepended from a template file (e.g., `extensions/core/claudemd-header.md`)

**Template-based generation vs section-merge approach**:

| Aspect | Current (section-merge) | Recommended (full generation) |
|--------|------------------------|-------------------------------|
| State tracking | Complex section markers | Simple: list of loaded extensions |
| Idempotency | Not guaranteed (depends on marker placement) | Guaranteed (regenerate from scratch) |
| Drift risk | High (manual maintenance) | None (always reflects loaded state) |
| Size control | Hard (sections accumulate) | Easy (regenerate enforces total budget) |
| Rollback | Re-inject from extension file | Re-run generation |
| Implementation complexity | High (regex-based section replace) | Low (concatenate EXTENSION.md files) |

**Version tracking**: The generated CLAUDE.md should include a generation timestamp and list
of loaded extensions at the top, enabling audit of "what was loaded when."

```markdown
<!-- Generated: 2026-04-16T10:30:00Z -->
<!-- Loaded: core@3.0.0, nvim@1.0.0, memory@1.0.0 -->
```

---

## Migration Strategy

### Phase 1: Preparation (no file moves yet)

1. **Audit cross-references**: Scan all scripts for hardcoded paths like
   `.claude/agents/`, `.claude/skills/` etc. These will need updating.
2. **Identify path-dependent tests**: The doc-lint script checks for files inside
   `extensions/*/` directories. Verify it will pass with the new layout.
3. **Write core EXTENSION.md**: Draft following the slim standard (<60 lines).
   The content should match the current "Core Components" section of README.md.
4. **Establish core version**: Tag current state as `core@3.0.0` in manifest.json.

### Phase 2: Physical Migration (the main work)

Move files in this order to minimize breakage:

```
Step 1: Create .claude/extensions/core/ subdirectories
  mkdir -p .claude/extensions/core/{agents,commands,skills,rules,context,scripts,hooks}

Step 2: Move file categories one at a time (git mv for clean history)
  git mv .claude/agents/* .claude/extensions/core/agents/
  git mv .claude/commands/* .claude/extensions/core/commands/
  git mv .claude/skills/skill-*/ .claude/extensions/core/skills/
  git mv .claude/rules/* .claude/extensions/core/rules/
  git mv .claude/scripts/* .claude/extensions/core/scripts/
  git mv .claude/hooks/* .claude/extensions/core/hooks/
  # context is large; move subdirectory by subdirectory

Step 3: Add EXTENSION.md and update manifest.json
  - Remove "virtual": true from manifest
  - Add EXTENSION.md
  - Update provides paths (relative to extensions/core/)

Step 4: Update Lua loader
  - Remove virtual extension fast-path in init.lua
  - Add core as auto-loaded extension (loaded before picker is shown)
  - Remove get_core_provides() from manifest.lua (use real manifest instead)

Step 5: Verify and fix cross-references
  - Update scripts that reference hardcoded .claude/agents/ etc.
  - Update context @-references in agent files
  - Run check-extension-docs.sh
```

### Backward Compatibility

During the transition, the system must continue to work for existing repos that have
already synced core files into `.claude/` directly. Strategy:

- The sync system targets the *installed* locations (`.claude/agents/` etc.), not the
  source locations. After migration, "sync from source repo" means "copy from
  extensions/core/ to .claude/ in target repos."
- For existing target repos (already have `.claude/agents/`), the sync behavior is
  unchanged — files are still copied to the same destinations.
- No action needed in target repos. The change is only in the source repo layout.

**Backward compatibility period**: Not needed. The sync destination is unchanged.
Existing target repos continue to receive files at `.claude/agents/` etc.

### Testing Strategy

1. **Pre-migration baseline**: Document current state (file counts, extension load test)
2. **Post-migration smoke test**: Load each extension via picker, verify no errors
3. **Sync round-trip test**: After migration, run "Load Core Agent System" into a test
   repo, verify same file set arrives as before migration
4. **CLAUDE.md generation test**: Load/unload extensions, verify CLAUDE.md content matches
5. **Dependency resolution test**: Verify nvim extension still auto-loads core

---

## Recommended Scope

### Include in This Task (Task 465)

1. Physical file migration (agents, commands, skills, rules, scripts, hooks — all 175+ files)
2. Core EXTENSION.md creation
3. Remove virtual flag machinery from Lua loader
4. Update manifest.json to remove `"virtual": true`
5. Computed CLAUDE.md generation (if feasible within scope — high value, moderate complexity)
6. Update doc-lint script to remove virtual exemptions
7. Core version established as `3.0.0`

### Defer to Follow-Up Tasks

- Profile-based extension sets (separate /profile command)
- Version compatibility enforcement (needs semver contract definition first)
- Marketplace metadata files
- Lazy/optional dependencies
- Extension health dashboard

### Non-Goals for This Task

- Changing how extensions are loaded in *target* repos (sync destination unchanged)
- Modifying the OpenCode parallel system (separate concern)
- Adding new extensions or changing extension content

---

## Confidence Level

**Overall confidence: High**

The strategic direction (physical migration, remove virtual flag, computed CLAUDE.md) is
well-justified and clearly beneficial. The implementation path is clear. The main uncertainty
is in the execution details:

- How many cross-references need updating? (Estimate: 15-25 script/context file changes)
- Does computed CLAUDE.md generation interact with the OpenCode sync system? (Likely yes,
  needs investigation during implementation)
- Are there hardcoded path assumptions in the sync allow-list that would break? (Low risk —
  the allow-list was designed to work with manifests, not hardcoded paths)

Risks are execution risks, not design risks. The architecture is sound.

**Specific confidence levels**:
- Physical migration is correct path: **High**
- Remove virtual flag: **High** (it was always transitional)
- Computed CLAUDE.md: **Medium-High** (correct direction, implementation needs care)
- Profile support: **Medium** (good idea, but scope would balloon this task)
- Version compatibility: **Medium** (important long-term, but premature now)
