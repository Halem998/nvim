# Teammate B Findings: Cross-Linking and Consistency

Task 475 - Review extension documentation and manifests
Research focus: cross-linking patterns, style consistency, routing_exempt analysis

---

## Key Findings

1. **Two broken `@`-references in `nix/README.md`** -- the only genuine broken cross-links found.
2. **`routing_exempt` is used only by `check-extension-docs.sh`** -- it has no effect on the
   `<leader>ac` picker. The task description's premise about routing_exempt controlling picker
   visibility is incorrect.
3. **`slidev` is the only extension correctly omitting `routing_exempt`** while having no routing
   block -- because it has zero skills, which is the correct condition. No other extension needs
   `routing_exempt`.
4. **Style is largely consistent** across the 10 "standard domain" extensions, with three
   structural outliers (memory, epidemiology, present) that deviate significantly.
5. **Installation wording diverges** from the template: all READMEs say "extension picker" but
   the template says `<leader>ac`.
6. **Only `core/README.md` has a "Related Documentation" section** -- this section is absent from
   all 15 other extensions.
7. **`index-entries.json` integrity is clean**: all 16 extensions have valid source paths.
8. **routing_exempt is undocumented**: not mentioned in any .md guide or schema reference.

---

## Style Analysis

### Section structure overview

The template (`core/templates/extension-readme-template.md`) defines a section-applicability
matrix with "simple" vs "complex" extension categories. Observed compliance:

| Section | Template Guidance | Present in how many |
|---------|------------------|---------------------|
| Overview table | Required | 14/16 (not memory, not slidev in standard form) |
| Installation | Required | 11/16 (core, memory, epidemiology, present, slidev omit) |
| MCP Tool Setup | Complex only if MCP | 5/16 (nix, lean, filetypes, founder, memory) |
| Commands | Complex if commands exist | 11/16 (correct: only those with commands) |
| Architecture tree | Complex; optional simple | 7/16 |
| Skill-Agent Mapping | Required | 11/16 |
| Language Routing | Required | 11/16 |
| Workflow | Complex only | 5/16 |
| Output Artifacts | Complex only | 6/16 |
| Key Patterns | Complex; optional simple | 8/16 |
| Rules Applied | If rules declared | 5/16 |
| Context References | Not in template | 4/16 (nix, nvim, web, formal) |
| Related Documentation | Not in template | 1/16 (core only) |
| References | Optional | 13/16 |

**Standard-compliant extensions**: latex, python, typst, z3 (simple); formal, nix, nvim, lean,
filetypes, web (complex).

**Structural outliers**:

- **memory** (291 lines): Completely different structure. Uses "The Three Commands", "Best
  Practices", "Troubleshooting", "Navigation", "Subdirectories" -- user-guide style. No
  Skill-Agent Mapping, no Language Routing, no Architecture section.

- **epidemiology** (70 lines): Uses "Compound Routing", "File Inventory" (unique sections).
  Missing Installation, Architecture, Language Routing, Workflow. Has "Command" (singular)
  instead of "Commands".

- **present** (88 lines): Has a Table of Contents (unique among all 16). Missing Skill-Agent
  Mapping, Language Routing, Architecture, Workflow, Output Artifacts, Installation. Defers to
  EXTENSION.md for content.

- **founder** (408 lines): Has "What's New in v3.0" section -- violates documentation-standards.md
  prohibition on version history. Missing Skill-Agent Mapping and Language Routing sections
  despite 15 skills.

- **slidev** (85 lines): Appropriate for a resource-only extension but uses non-standard headers
  ("Purpose", "Resource Catalog", "Dependency Usage", "Consuming Extensions").

### Installation wording inconsistency

Template specifies: `Loaded via \`<leader>ac\` in Neovim.`
All 11 READMEs with Installation sections say: `Loaded via the extension picker.`

These are inconsistent. The template is more specific about the keybinding; the READMEs are more
generic. The template's wording is more actionable for a user who doesn't know the command.

### "Context References" section (not in template)

Four extensions have this section listing `@.claude/extensions/*/context/...` paths: nix, nvim,
web, formal. The other 12 extensions with context files do not have it. This is an inconsistently
applied pattern that exists outside the official template.

---

## Cross-Linking Assessment

### Dependency graph (manifest `dependencies` field)

All 15 domain extensions declare `["core"]`. Two additionally depend on `slidev`:
- `founder` -> `["core", "slidev"]`
- `present` -> `["core", "slidev"]`

`slidev/README.md` has a "Consuming Extensions" section listing founder and present -- correct.
Neither `founder/README.md` nor `present/README.md` explicitly mentions the slidev dependency.

### `@`-reference cross-links in READMEs

**Broken (2)** -- both in `nix/README.md` "Context References" section:
```
STATED:  @.claude/extensions/nix/context/project/nix/patterns/modules.md
ACTUAL:  module-patterns.md

STATED:  @.claude/extensions/nix/context/project/nix/tools/nixos-rebuild.md
ACTUAL:  nixos-rebuild-guide.md
```

**All other `@`-references** (12 total across formal, nvim, web READMEs) resolve correctly.

### Relative markdown links

All relative markdown links in all extension READMEs resolve correctly. No broken internal links.

### Extension-to-extension prose references

- `core/README.md` mentions formal, nix, nvim as domain extension examples
- `formal/README.md` mentions `lean` extension for `.lean` file tasks
- `slidev/README.md` lists founder and present as consumers
- No other inter-extension prose cross-links found

### Missing cross-references

- No extension README links up to `extensions/README.md` (the parent index)
- Only `memory/README.md` has a parent-directory link (adopting nvim documentation-policy pattern)
- `founder` and `present` do not reference their `slidev` dependency in prose

### index-entries.json integrity

All 16 extensions were validated: every path in every `index-entries.json` correctly resolves
to a file in the extension's own `context/` subdirectory. No orphaned or invalid index entries.

The 139 entries in the live `context/index.json` reflect only the 4 currently-loaded extensions
(core=100, nix=11, nvim=23, memory=6). All other extensions merge their entries when loaded --
this is correct by design (lazy loading), not a gap.

---

## routing_exempt Analysis

### What routing_exempt does

`routing_exempt` is a manifest flag consumed **exclusively** by
`.claude/scripts/check-extension-docs.sh`. When `true`, the script skips `check_routing_block()`,
which verifies that extensions declaring skills also have a `routing` block.

Relevant code (lines 113-128 of check-extension-docs.sh):
```bash
# Skip extensions that declare routing_exempt: true
is_exempt=$(jq -r '.routing_exempt // false' "$manifest" 2>/dev/null)
if [[ "$is_exempt" == "true" ]]; then
  info "routing_exempt: skipping routing block check"
  return
fi
# If manifest declares non-empty provides.skills, verify routing block exists
skill_count=$(jq -r '.provides.skills | length' "$manifest" 2>/dev/null)
if [[ "$skill_count" -gt 0 ]]; then
  has_routing=$(jq -r 'has("routing")' "$manifest" 2>/dev/null)
  if [[ "$has_routing" == "false" ]]; then
    fail "manifest declares $skill_count skill(s) but has no routing block"
  fi
fi
```

**The flag has zero effect on the Neovim picker.** The `list_available()` function in
`lua/neotex/plugins/ai/shared/extensions/init.lua` reads all manifests via `manifest_mod.list_extensions()`
and applies no filter based on `routing_exempt`. Core appears in the picker alongside all other
extensions. The task description's claim that `routing_exempt` controls what the picker loads is
a mischaracterization.

### Current status matrix

| Extension | routing_exempt | skills | routing block | Assessment |
|-----------|---------------|--------|---------------|------------|
| core | `true` | 16 | absent | CORRECT -- routing handled by hardcoded orchestrator |
| slidev | absent | 0 | absent | PASSABLE but inconsistent (no skills means check never triggers) |
| all 14 others | absent | 2-15 | present | CORRECT |

### Should slidev have routing_exempt?

`slidev` currently passes the doc-lint check coincidentally (the check only triggers when
`skill_count > 0`). However, `slidev` is infrastructure-only like `core`. For consistency
with `core`'s explicit declaration, `slidev` could be given `routing_exempt: true`. This
would make the "I'm infrastructure, not a routable domain" intent explicit rather than
relying on the absence-of-skills bypass path.

This is a minor improvement, not a requirement.

### routing_exempt is undocumented

The flag does not appear in:
- `context/guides/extension-development.md` (the manifest field table omits it)
- `docs/guides/creating-extensions.md`
- `docs/architecture/extension-system.md`
- Any other `.md` file in the repo

It exists only in `core/manifest.json` and `check-extension-docs.sh`. New extension authors
would have no way to discover this field exists or know when to use it.

---

## Evidence / Examples

### Broken nix cross-references

From `nix/README.md` lines 178-181:
```
## Context References
- `@.claude/extensions/nix/context/project/nix/domain/nix-language.md`   <- OK
- `@.claude/extensions/nix/context/project/nix/domain/flakes.md`          <- OK
- `@.claude/extensions/nix/context/project/nix/patterns/modules.md`       <- BROKEN
- `@.claude/extensions/nix/context/project/nix/tools/nixos-rebuild.md`    <- BROKEN
```

Actual files that exist:
- `.../nix/patterns/module-patterns.md`
- `.../nix/tools/nixos-rebuild-guide.md`

### memory README style mismatch

`memory/README.md` sections: "The Three Commands", "Writing Memories", "Reading Memories",
"Storage Details", "Example", "Connections", "Configuration", "Troubleshooting", "Best Practices",
"Subdirectories", "Navigation".

None of these are template sections. The "Subdirectories" and "Navigation" sections specifically
match the nvim `documentation-policy.md` format (designed for Lua source code directories).

### founder version-history violation

`founder/README.md` opens with:
```markdown
# Founder Extension (v3.0)
## What's New in v3.0
- Unified Phased Workflow: All 8 commands...
- Breaking Changes: project-agent is now research-only...
```

`documentation-standards.md` states: "Do not include historical information about past versions",
"Do not mention 'we changed X to Y'", "Do not add 'Version History' sections."

### Template-reality wording divergence (Installation)

Template: `Loaded via \`<leader>ac\` in Neovim.`
Actual: `Loaded via the extension picker.` (11 extensions)
Memory: `Extension picker -> select "memory"` (code block style)

Three different phrasings for the same action.

---

## Confidence Level

**High** for:
- routing_exempt behavior (verified by reading Lua source, bash script)
- Broken nix @-references (filesystem verified)
- Section presence/absence analysis (all 16 READMEs measured directly)
- index-entries.json integrity (all 16 validated programmatically)
- Dependency graph (all manifests inspected)

**Medium** for:
- Whether memory/epidemiology/present deviations are intentional vs. oversight
- Whether adding "Context References" to all complex extensions is needed
- Whether the template or README wording should win for Installation

**Low** for:
- Whether slidev should have `routing_exempt: true` (both options are defensible)
- Whether `latex` should have Workflow/Output Artifacts (template says optional for simple)
