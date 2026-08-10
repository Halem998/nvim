# Research Report: Task #182 (Supplemental)

**Task**: 182 - Fix Website opencode multi-extension agent dependency
**Date**: 2026-03-11
**Focus**: Extension overlap and dependency management
**Supplements**: [research-001.md](research-001.md)

## Summary

Analyzed all 12 extensions across both `.claude/` and `.opencode/` systems for artifact overlap, reviewed the extension loader architecture, and researched industry patterns for plugin dependency management. The current system has no dependency resolution -- each extension operates independently. The task 182 approach (Option B: self-contained extensions with duplicated agents) is the pragmatic choice given the current architecture, but this research identifies patterns that could inform future evolution if cross-extension dependencies become more common.

## Findings

### 1. Current Extension Overlap Analysis

**Extensions across systems**: 11 extensions exist in both `.claude/` and `.opencode/` (epidemiology, filetypes, formal, latex, lean, nix, nvim, python, typst, web, z3). One extension (`memory`) is opencode-only.

**Agent overlap today**: The only cross-extension artifact overlap is the `document-converter-agent.md` which was added to the opencode `web` extension (commit `0869417e`). This agent does not exist in the claude `web` extension. The plan (implementation-002.md) will add `neovim-research-agent.md` and `neovim-implementation-agent.md` to the web extension, creating intentional duplication with the `nvim` extension.

**No other overlaps detected**: Every other agent, skill, command, and rule is unique to its extension. No two extensions provide the same artifact filename.

**Skill uniqueness**: All 29 claude skills and 30 opencode skills have unique names. No skill name conflicts exist across extensions.

### 2. Extension Loader Architecture

The extension system uses a **parameterized shared architecture** (`lua/neotex/plugins/ai/shared/extensions/`):

- **config.lua**: Defines per-system presets (claude vs opencode) with different base dirs, agent subdirs, merge target keys
- **loader.lua**: File copy engine -- copies agents, skills, commands, rules, context, scripts, data directories
- **manifest.lua**: Extension discovery from global extensions directory
- **state.lua**: Tracks loaded state, installed files, merged sections per project
- **merge.lua**: Handles section injection into CLAUDE.md/AGENTS.md, settings merge, index.json entries
- **verify.lua**: Post-load verification
- **init.lua**: Public API creating manager instances with load/unload/reload/verify operations

Key characteristics:
- **No dependency resolution**: The `dependencies` field exists in manifest.json but is an empty array for all 12 extensions. The loader does not process it.
- **No shared artifacts**: Extensions cannot reference artifacts from other extensions.
- **Conflict detection**: The loader checks for file conflicts before loading (overwrite warnings) but has no concept of shared ownership.
- **Atomic rollback**: Failed loads are rolled back (files removed, merges reversed).
- **Portable state**: Installed file paths stored as relative paths in extensions.json.

### 3. Industry Patterns for Extension Dependencies

Research identified five primary patterns used in production systems:

#### Pattern A: Declarative Dependencies (WordPress 6.5, VSCode, Jenkins)

The most common pattern. Extensions declare required dependencies in metadata:
```json
{
  "dependencies": ["extension-a", "extension-b"]
}
```

**How it works**: The system prevents activation unless dependencies are loaded first. Does not auto-install but blocks activation and provides UI guidance.

**Pros**: Simple to implement, clear semantics, prevents broken states.
**Cons**: Still requires manual user action to load dependencies; does not solve the "reload problem" (unloading core doesn't auto-unload dependents).

**Relevance**: This matches the existing `dependencies` field in manifest.json. Could be implemented with minimal changes to the loader.

#### Pattern B: Extension Packs (VSCode)

A meta-extension that bundles related extensions:
```json
{
  "extensionPack": ["web", "nvim", "memory"]
}
```

**How it works**: Loading the pack loads all bundled extensions. Unloading the pack unloads all. Extensions remain independently manageable.

**Pros**: Single-action load for common combinations; extensions stay modular.
**Cons**: Adds a layer of indirection; users need to understand packs vs individual extensions.

**Relevance**: Could create a "website-stack" pack that loads web+nvim+memory together. More elegant than duplication but requires new loader logic.

#### Pattern C: Self-Contained Extensions with Duplication (Current Approach)

Each extension includes all artifacts it needs, even if some overlap with other extensions:
```json
{
  "provides": {
    "agents": ["web-impl.md", "web-research.md", "neovim-impl.md", "neovim-research.md"]
  }
}
```

**How it works**: No cross-extension awareness needed. Each extension is fully portable.

**Pros**: Simplest to implement; no loader changes; maximum portability; no "reload problem".
**Cons**: File duplication; potential for copies to diverge; larger extensions.

**Relevance**: This is Option B from the existing plan. Appropriate for the current scale (2-3 duplicated agents).

#### Pattern D: Shared Artifact Registry

A central registry that maps artifact names to providing extensions:
```json
{
  "agents": {
    "neovim-research-agent": { "canonical": "nvim", "also_used_by": ["web"] }
  }
}
```

**How it works**: When `web` loads, the registry resolves `neovim-research-agent` to the `nvim` extension's copy. If `nvim` is already loaded, the file is shared. If not, it is copied from the canonical source.

**Pros**: Single source of truth; no divergence; efficient.
**Cons**: Complex to implement; introduces tight coupling between extensions; harder to reason about state.

**Relevance**: Overkill for the current scale. Would be appropriate if 5+ extensions needed to share agents.

#### Pattern E: Auto-Cascade Load/Unload (RabbitMQ)

Loading an extension automatically loads its dependencies. Unloading triggers cascade unload of dependents:

**How it works**: `rabbitmq-plugins enable plugin_a` automatically enables all dependencies. Disabling checks for dependents first.

**Pros**: Fully automatic; prevents broken states; clean lifecycle.
**Cons**: Complex dependency graph management; users may be surprised by cascade effects; circular dependency risk.

**Relevance**: Most sophisticated approach but requires significant loader changes and circular dependency detection (Kahn's algorithm or similar).

### 4. Evaluation Matrix for This Project

| Criterion | A: Declarative | B: Packs | C: Self-Contained | D: Registry | E: Auto-Cascade |
|-----------|:-:|:-:|:-:|:-:|:-:|
| Implementation effort | Low | Medium | None | High | High |
| Solves reload problem | No | Partial | Yes | Yes | Yes |
| Portability | Good | Good | Best | Medium | Medium |
| Maintenance burden | Low | Low | Low-Medium | Medium | Medium |
| Scale suitability | Good | Good | Good (small N) | Best (large N) | Best (large N) |
| Loader changes needed | Minimal | Moderate | None | Major | Major |

### 5. Current Scale Assessment

- **Total extensions**: 12
- **Extensions with cross-dependencies**: 1 (web needs nvim agents)
- **Duplicated artifacts**: 3 files (after task 182 implementation)
- **Total agent files**: ~28 unique agents

At this scale, **Pattern C (self-contained)** is appropriate. The duplication cost is 2 additional markdown files (~25KB). The maintenance cost is documented update workflow.

### 6. Future Threshold for Architecture Change

Consider evolving to Pattern A (declarative dependencies) if:
- 3+ extensions need artifacts from other extensions
- Duplicated agent count exceeds 8-10 files
- Agent definitions begin diverging between extensions
- Users report confusion about which extensions to load

Consider Pattern B (extension packs) if:
- Common multi-extension combinations emerge (e.g., "full-stack" = web+nvim+memory)
- Users frequently forget to load companion extensions

## Recommendations

1. **Proceed with Option B (self-contained web extension)** as planned in implementation-002.md. The current scale does not justify architectural changes.

2. **Document canonical source**: Add a comment header to duplicated agents indicating the canonical source extension:
   ```markdown
   <!-- Canonical source: nvim extension. Duplicated in web extension for portability. -->
   ```

3. **Keep the `dependencies` field**: The manifest.json already has an empty `dependencies` array. Future work can populate it without schema changes.

4. **Monitor divergence**: When updating neovim agents in the `nvim` extension, check if the `web` extension copies need updating. This is a manual process at current scale.

5. **Extension pack as future option**: If a third extension needs nvim agents, consider creating an "extension pack" mechanism rather than continuing to duplicate.

## References

- [Plugin Architecture Overview (dotCMS)](https://www.dotcms.com/blog/plugin-achitecture) - Core plugin architecture patterns
- [WordPress 6.5 Plugin Dependencies](https://make.wordpress.org/core/2024/03/05/introducing-plugin-dependencies-in-wordpress-6-5/) - Declarative dependency pattern
- [VSCode Extension Manifest](https://code.visualstudio.com/api/references/extension-manifest) - extensionDependencies and extensionPack patterns
- [RabbitMQ Plugins](https://deepwiki.com/rabbitmq/rabbitmq-server/7-plugins-and-extensions) - Auto-cascade dependency resolution
- [Apache NiFi Extension System](https://deepwiki.com/apache/nifi/3-extension-system) - NAR-based extension isolation
- [ArjanCodes Plugin Architecture](https://arjancodes.com/blog/best-practices-for-decoupling-software-using-plugins/) - Decoupling best practices
- [VSCode Extension Dependencies Blog](https://www.darrenlester.com/blog/declaring-vscode-extension-dependencies) - Practical dependency patterns

## Next Steps

- Proceed with implementation-002.md Phase 1 (copy neovim agents to web extension)
- Add canonical source comments to duplicated agents
- Consider monitoring mechanism for agent divergence
