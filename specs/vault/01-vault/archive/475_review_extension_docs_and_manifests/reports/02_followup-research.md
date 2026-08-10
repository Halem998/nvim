# Follow-Up Research Report: Task 475

**Date**: 2026-04-17
**Focus**: README loading risks, stale content fixes, cross-linking plan

---

## Section 1: README Loading Risks

### How Extension Files Are Loaded

There are two distinct loading paths:

**Path A: Lua loader (production)** -- `lua/neotex/plugins/ai/shared/extensions/loader.lua`

The `copy_simple_files()` function (line 90) iterates over `manifest.provides[category]` arrays.
Only files **explicitly listed** in the manifest are copied. A `README.md` in
`extensions/foo/commands/` will NOT be copied unless it appears in `manifest.provides.commands`.

**Path B: install-extension.sh (legacy/development tool)** -- `.claude/scripts/install-extension.sh`

The `install_commands()` function (line 85) uses:
```bash
for cmd in "$commands_dir"/*.md; do
```
This glob matches ALL `.md` files including `README.md`. Similarly, `install_agents()` (line 157)
uses `"$agents_dir"/*.md`, which would copy a `README.md` from an agents directory.

**Conclusion**: The production loader (Lua) is safe -- it is manifest-driven. The
`install-extension.sh` script has a real risk: it would copy `README.md` into `.claude/commands/`
or `.claude/agents/` if one exists in those directories.

### Current State: README.md Already in `.claude/agents/`

**CONFIRMED RISK**: `.claude/agents/README.md` exists in the runtime directory.

Source: `extensions/core/agents/README.md`
Why it's there: `core/manifest.json` explicitly lists `"README.md"` in `provides.agents` (line 25).
The Lua loader dutifully copies it.

**Impact analysis**: Claude Code scans `.claude/agents/` for agent definitions. An agent is
recognized by its YAML frontmatter (`name:`, `description:`). The current `agents/README.md`
has no frontmatter -- just a markdown heading. This means Claude Code ignores it as an agent,
but it is wasteful (extra file in a scanned directory) and sets a bad precedent.

**Key risk for `install-extension.sh`**: If someone runs `install-extension.sh` against the
`memory` extension, the `memory/commands/README.md` would be symlinked to
`.claude/commands/README.md`. Claude Code reads `.claude/commands/` for slash commands.
A file named `README.md` could be registered as a `/README` command (or silently ignored,
depending on how Claude Code handles non-frontmatter files in that directory). Either outcome
is undesirable.

### Risk Matrix

| File | Risk Path | Risk Level | Current Impact |
|------|-----------|------------|----------------|
| `core/agents/README.md` | Lua loader (explicitly listed in manifest) | MEDIUM | File exists in `.claude/agents/` now |
| `memory/commands/README.md` | install-extension.sh glob | HIGH | Not symlinked (Lua loader doesn't create symlinks; install-extension.sh not used in production) |
| `memory/skills/README.md` | install-extension.sh glob | LOW | Skills use directory matching, not *.md glob |
| `memory/skills/skill-memory/README.md` | install-extension.sh glob | LOW | Deep inside skill dir; glob only matches top-level |
| `core/context/README.md` | Lua loader (listed in manifest `provides.context`) | LOW | Context READMEs are not scanned for commands/agents |
| `core/docs/templates/README.md` | Lua loader (listed in manifest `provides.docs`) | LOW | Docs dir not scanned for commands/agents |

### Recommended Fixes for Loading Risks

**Fix 1 (HIGH)**: Remove `"README.md"` from `core/manifest.json` `provides.agents`.
This removes the active copy from `.claude/agents/README.md`.

**Fix 2 (HIGH)**: Remove `"README.md"` from `core/manifest.json` `provides.context`.
The context README describes directory structure for humans; it should not be in the runtime.

**Fix 3 (MEDIUM)**: Fix `install-extension.sh` to exclude README.md from glob matches:
```bash
# Change:
for cmd in "$commands_dir"/*.md; do
# To:
for cmd in "$commands_dir"/*.md; do
  [[ "$(basename "$cmd")" == "README.md" ]] && continue
```
Apply same fix to `install_agents()`.

**Fix 4 (LOW)**: Delete `.claude/agents/README.md` from the runtime (artifact of current broken state).
This will happen automatically if Fix 1 is applied and the extension is reloaded.

---

## Section 2: Subdirectory README Inventory

All `README.md` files below extension root level:

### `core` Extension

| Path | Directory Type | Risk | Disposition |
|------|---------------|------|-------------|
| `core/agents/README.md` | agents/ | MEDIUM -- listed in manifest `provides.agents`; gets copied to runtime | **Remove from manifest; keep as human-readable source doc** |
| `core/context/README.md` | context/ | LOW -- listed in manifest `provides.context`; not a command dir | Keep, but remove from manifest |
| `core/context/checkpoints/README.md` | context subdirectory | None | Keep as human-readable |
| `core/context/reference/README.md` | context subdirectory | None | Keep as human-readable |
| `core/docs/README.md` | docs/ | LOW -- listed in manifest `provides.docs` | Fine in docs/ |
| `core/docs/templates/README.md` | docs/templates/ | None | Keep |

### `memory` Extension

| Path | Directory Type | Risk | Disposition |
|------|---------------|------|-------------|
| `memory/commands/README.md` | commands/ | HIGH -- would be symlinked by install-extension.sh | **Remove (redundant nav doc; commands listed in extension root README)** |
| `memory/context/README.md` | context/ | None | Keep |
| `memory/context/project/memory/README.md` | context subdirectory | None | Keep |
| `memory/skills/README.md` | skills/ | LOW | Remove (redundant) |
| `memory/skills/skill-memory/README.md` | skills subdirectory | None | Keep (SKILL.md is more authoritative; README may confuse) |
| `memory/data/.memory/README.md` | data directory | None | Keep (vault documentation) |
| `memory/data/.memory/00-Inbox/README.md` | vault subdirectory | None | Keep |
| `memory/data/.memory/10-Memories/README.md` | vault subdirectory | None | Keep |
| `memory/data/.memory/20-Indices/README.md` | vault subdirectory | None | Keep |
| `memory/data/.memory/30-Templates/README.md` | vault subdirectory | None | Keep |
| `memory/data/README.md` | data/ | None | Keep |

### Domain Extensions (context subdirectory READMEs)

These exist in `context/project/` subdirectories and have no loading risk. They are human
navigation aids. No action needed.

| Extension | Path | Disposition |
|-----------|------|-------------|
| `epidemiology` | `context/project/epidemiology/README.md` | Keep |
| `filetypes` | `context/project/filetypes/README.md` | Keep |
| `formal` | `context/project/logic/README.md`, `math/README.md`, `physics/README.md` | Keep |
| `founder` | `context/project/founder/README.md`, `founder/deck/README.md` | Keep |
| `latex` | `context/project/latex/README.md` | Keep |
| `lean` | `context/project/lean4/README.md` | Keep |
| `nix` | `context/project/nix/README.md` | Keep |
| `nvim` | `context/project/neovim/README.md` | Keep |
| `present` | `context/project/present/README.md`, `talk/templates/*/README.md` | Keep |
| `python` | `context/project/python/README.md` | Keep |
| `typst` | `context/project/typst/README.md` | Keep |
| `web` | `context/project/web/README.md` | Keep |
| `z3` | `context/project/z3/README.md` | Keep |

### Summary: Files to Remove

1. **`core/manifest.json`**: Remove `"README.md"` from `provides.agents` (line 25)
2. **`core/manifest.json`**: Optionally remove `"README.md"` from `provides.context` (line 114)
3. **`memory/commands/README.md`**: Delete file entirely (redundant; poses install-extension.sh risk)
4. **`memory/skills/README.md`**: Delete file (redundant navigation doc)
5. **`.claude/agents/README.md`**: Delete from runtime (stale artifact; auto-fixed on reload after manifest fix)

---

## Section 3: Stale Content Fixes

### 3.1 `founder/README.md`: Missing `/consult` Command

**Problem**: The README was written for v3.0 but `/consult` was added later. The command table
(lines 16-27), architecture tree (lines 216-292), and "All 8 commands" language (line 7, 302)
all omit `/consult`.

**Evidence**: `founder/manifest.json` lists `consult.md` in `provides.commands` (line 55) and
`skill-consult` in `provides.skills` (line 43). `founder/commands/consult.md` exists.

**Exact fixes needed**:

**Line 9** (command count): Change "eight commands" to "nine commands"

**Lines 16-27** (command table): Add row after the `/sheet` row:
```
| `/consult` | Collaborative design consultation with domain expert perspective | Consultation report |
```

**Lines 229-231** (architecture tree, commands section): Add after `sheet.md`:
```
│   └── consult.md            # /consult command (standalone immediate-mode)
```

**Line 302** ("All 5 commands"): This says "All 5 commands follow the same lifecycle" which is
wrong in two ways -- (a) there are 9 commands (b) `/consult` does NOT follow the
research/plan/implement lifecycle. Change to "Eight commands follow the phased lifecycle.
`/consult` operates in standalone immediate-mode (no task pipeline)."

**Lines 332-340** (Per-Type Research Agents table): Add row:
```
| /consult | legal-analysis-agent | Legal AI product description analysis |
```

**Lines 382-393** (Output Artifacts): Add `/consult` to Task Mode table or note it generates
`strategy/consultation-report-{slug}.md`.

### 3.2 `memory/README.md`: Stale `--remember` Model

**Problem**: The README describes an explicit `--remember` flag model that no longer exists.
The actual implementation uses automatic memory retrieval during research/plan/implement preflight.

**Stale sections**:

- **Line 22**: "You must pass `--remember` explicitly to have memories included"
- **Lines 68-89**: Entire "During Research" subsection describes `--remember` flag
- **Line 22** in table: Shows "Read" operation as `/research N --remember`

**Correct model** (from CLAUDE.md and `skill-memory/README.md`):
Memory retrieval is **automatic**. When the memory extension is loaded, the `/research`, `/plan`,
and `/implement` preflight stages call `memory-retrieve.sh` to inject relevant memories as
`<memory-context>` into agent context. The `--clean` flag suppresses auto-retrieval.
There is no `--remember` flag.

**Exact fixes needed**:

**Lines 17-27** (table): Replace entire "Read" row:

Old:
```
| **Read** | `/research N --remember` | Before starting work, to surface relevant prior knowledge |
```
New:
```
| **Read** | (automatic) | Memories auto-injected into `/research`, `/plan`, `/implement` preflight |
```

**Line 22**: Delete the "Important" block that begins "Memories are NOT automatically injected
into every session. The vault is passive. You must pass `--remember` explicitly..."
Replace with:
```
**Important**: Memories ARE automatically injected into `/research`, `/plan`, and `/implement`
when the extension is loaded. Use `--clean` to suppress auto-retrieval for a specific session.
```

**Lines 67-89**: Replace the "During Research" subsection:

Old section title and content reference `--remember` flag.
New content:
```markdown
### Automatic Retrieval

When the memory extension is loaded, `/research`, `/plan`, and `/implement` automatically
inject relevant memories into agent context. The preflight stage calls `memory-retrieve.sh`
to search the vault and prepend results as `<memory-context>`.

Use the `--clean` flag to suppress auto-retrieval for a specific invocation:

```bash
/research 42 --clean  # Skip memory retrieval for this research run
```

### Manual Access

Since memories are plain markdown files, you can also:
...
```

### 3.3 `nix/README.md`: Two Broken `@`-References

**Problem**: Lines 175-178 reference context files using stale names.

**Confirmed actual filenames** (from `ls`):
- `context/project/nix/patterns/` contains: `derivation-patterns.md`, `module-patterns.md`, `overlay-patterns.md`
- `context/project/nix/tools/` contains: `home-manager-guide.md`, `nixos-rebuild-guide.md`

**Exact fixes**:

**Line 177**: Change `nix/patterns/modules.md` to `nix/patterns/module-patterns.md`
```
Old: - `@.claude/extensions/nix/context/project/nix/patterns/modules.md`
New: - `@.claude/extensions/nix/context/project/nix/patterns/module-patterns.md`
```

**Line 178**: Change `nix/tools/nixos-rebuild.md` to `nix/tools/nixos-rebuild-guide.md`
```
Old: - `@.claude/extensions/nix/context/project/nix/tools/nixos-rebuild.md`
New: - `@.claude/extensions/nix/context/project/nix/tools/nixos-rebuild-guide.md`
```

### 3.4 `extensions/README.md` (root): Extension Count

**Current state**: Lists 15 extensions. Actual extension count is 16 (15 domain + `core`).

**Assessment**: The table at lines 22-37 lists all 15 non-core extensions correctly. The `core`
extension is intentionally omitted (it is infrastructure, not a user-facing extension). The
"8/16" characterization from the original research report was incorrect -- the README is
actually complete as written. **No fix needed.**

### 3.5 `extension-development.md`: Missing `routing_exempt` Field

**Problem**: The Manifest Fields table (lines 93-102) documents 8 fields but omits `routing_exempt`.

**Evidence**: `core/manifest.json` uses `"routing_exempt": true` (line 6). The
`check-extension-docs.sh` validator reads it (line 115). The field is real and documented
in state.json completion summaries but absent from the development guide.

**Exact fix** -- Add row to Manifest Fields table after the `merge_targets` row:

```
| `routing_exempt` | boolean | Optional. When `true`, skip routing block validation in doc-lint. Use for infrastructure extensions (like `core`) that handle routing via hardcoded orchestrator logic rather than manifest routing entries. |
```

Insert at line 103 (after the current last row of the table).

### 3.6 `present/README.md`: Missing Sections

**Problem**: The README is thin -- only 90 lines. It has Overview, Commands, and Related Files
sections but lacks Skill-Agent Mapping, Language Routing, Architecture tree, and Workflow.

**Evidence from `present/EXTENSION.md`**: Contains complete Skill-Agent Mapping table (9 skills),
Language Routing table (5 task types), and Talk Modes table.

**Sections to add**:

1. **Installation section** (after Overview): Standard boilerplate
2. **Architecture section**: Directory tree from EXTENSION.md content
3. **Skill-Agent Mapping** (copy from EXTENSION.md):
   - skill-grant, skill-budget, skill-timeline, skill-funds, skill-slides
   - + skill-slide-planning, skill-slide-critic
4. **Language Routing** (copy from EXTENSION.md): 5 rows (grant, budget, timeline, funds, slides)
5. **Talk Modes table** (from EXTENSION.md): CONFERENCE, SEMINAR, DEFENSE, POSTER, JOURNAL_CLUB

**Current "Related Files" section** should become part of a broader Architecture section or be
renamed. The link to `EXTENSION.md` in Related Files is a stopgap acknowledging the README is thin.

---

## Section 4: Cross-Linking Plan

### Current State

- Extension root READMEs have "Navigation: [Parent Directory](../README.md)" footer links
- `extensions/README.md` does NOT link to individual extension READMEs
- Extension READMEs do NOT mention their dependencies in prose (only manifest declares them)

### Recommended Improvements

**Priority 1: extensions/README.md -> individual extension READMEs**

Add a "Documentation" column to the Available Extensions table pointing to each extension's README:

```markdown
| Extension | Task Type | Description | Docs |
|-----------|----------|-------------|------|
| nvim | neovim | Neovim configuration development | [README](nvim/README.md) |
```

Or simpler: add a note at the end of each table row. This enables one-click navigation from
the hub to any extension.

**Priority 2: Extensions with dependencies should mention them**

`founder/README.md` depends on `slidev` extension. Add a note in the Architecture section or a
new "Dependencies" section:
```markdown
## Dependencies

This extension requires the `slidev` extension (loaded automatically when founder is loaded).
See [slidev/README.md](../slidev/README.md) for shared animation patterns and CSS presets.
```

Apply same pattern to `present/README.md` (also depends on `slidev`).

**Priority 3: present/README.md -> EXTENSION.md**

The "Related Files" section currently links to EXTENSION.md as a workaround for missing content.
Once the Skill-Agent Mapping and Language Routing sections are added to README.md, this link
should be removed or changed to note that EXTENSION.md is the CLAUDE.md source.

**Priority 4: Navigation footer standardization**

Most extension READMEs have a "Navigation" section with `[Parent Directory](../README.md)`.
The core agents/README.md additionally links to CLAUDE.md. Recommend standardizing: all
extension root READMEs should include a "See Also" or "Navigation" footer with links to:
- `[Extensions Hub](../README.md)` (parent)
- `[Extension Development Guide](../../context/guides/extension-development.md)` (for developers)

---

## Section 5: Template Compliance Matrix

From `core/templates/extension-readme-template.md`:

| Section | Simple | Complex | nvim | lean | nix | present | memory | founder |
|---------|--------|---------|------|------|-----|---------|--------|---------|
| Overview | Required | Required | ✓ | ✓ | ✓ | ✓ | -- | ✓ |
| Installation | Required | Required | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ |
| MCP Tool Setup | Omit | If MCP | N/A | N/A | ✓ | N/A | ✓ | ✓ |
| Commands | Omit if none | Required | N/A | N/A | N/A | ✓ | ✓ | ✓ |
| Architecture | Optional | Required | -- | -- | ✓ | ✗ | -- | ✓ |
| Skill-Agent Mapping | Required | Required | ✓ | ✓ | ✓ | ✗ | -- | ✓ |
| Language Routing | Required | Required | ✓ | ✓ | ✓ | ✗ | -- | ✓ |
| Workflow | Optional | Required | -- | ✓ | ✓ | ✗ | -- | ✓ |
| Output Artifacts | Omit | Required | -- | ✓ | ✓ | ✗ | -- | ✓ |
| Key Patterns | Optional | Required | ✓ | ✓ | ✓ | ✗ | -- | ✓ |
| References | Optional | Optional | -- | ✓ | ✓ | -- | -- | ✓ |

**Notes**:
- `✓` = present, `✗` = missing, `--` = not applicable or correctly omitted
- `memory` README is classified as complex but missing most required sections -- by design it
  uses a different structure focused on usage rather than architecture
- `present` is complex (5 task types, 9 agents, MCP integration) and is missing most required sections

**Template compliance issues**:
1. `present/README.md` -- missing Installation, Architecture, Skill-Agent Mapping, Language Routing, Workflow, Output Artifacts, Key Patterns (7 sections)
2. `memory/README.md` -- stale content (--remember model) regardless of template compliance

---

## Section 6: Recommended Implementation Phases

### Phase 1: Loading Safety (CRITICAL -- do first)

1. Remove `"README.md"` from `core/manifest.json` `provides.agents`
2. Delete `.claude/agents/README.md` from runtime (or it auto-clears on next reload)
3. Fix `install-extension.sh` to skip `README.md` in agent/command glob matches
4. Delete `memory/commands/README.md` (eliminate install-extension.sh risk)
5. Delete `memory/skills/README.md` (redundant, minor risk)

### Phase 2: Stale Content Fixes (HIGH -- correctness issues)

6. Fix `memory/README.md` to describe auto-retrieval model (remove all `--remember` references)
7. Fix `nix/README.md` two broken @-references (lines 177-178)
8. Add `/consult` to `founder/README.md` (command table, architecture tree, workflow table)

### Phase 3: Template Gaps (MEDIUM -- completeness)

9. Expand `present/README.md` with Skill-Agent Mapping, Language Routing, Architecture, Workflow sections
10. Add `routing_exempt` field to `extension-development.md` Manifest Fields table

### Phase 4: Cross-Linking (LOW -- discoverability)

11. Add README links to `extensions/README.md` Available Extensions table
12. Add Dependencies sections to `founder/README.md` and `present/README.md` (both depend on slidev)
13. Standardize Navigation footers in extension root READMEs

### Phase 5: Template Reference Fix (LOW -- developer ergonomics)

14. Update `extension-development.md` "Creating an Extension" section: change
    `See extensions/template/` to `See core/templates/extension-readme-template.md`
    (the template directory no longer exists; the template moved to core/templates/)
