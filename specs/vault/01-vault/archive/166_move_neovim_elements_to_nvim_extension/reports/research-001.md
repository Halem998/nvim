# Research Report: Task #166

**Task**: 166 - move_neovim_elements_to_nvim_extension
**Started**: 2026-03-10T00:00:00Z
**Completed**: 2026-03-10T00:30:00Z
**Effort**: 2-4 hours (implementation)
**Dependencies**: None
**Sources/Inputs**: Codebase exploration of .claude/ and .opencode/ systems
**Artifacts**: specs/166_move_neovim_elements_to_nvim_extension/reports/research-001.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Both .claude/ and .opencode/ have neovim-specific agents, skills, context files, and rules that need to move to a `nvim/` extension
- The extension pattern is well-established with 10+ existing extensions providing a clear template
- Key structural difference: .opencode/ extensions have README.md files at every directory level; .claude/ does not
- Beyond moving files, several wiring points must be updated: routing tables in commands, orchestration-core.md routing validation, CLAUDE.md/README.md references, and index.json entries
- The core index.json entries that reference neovim agents (return-metadata-file.md, anti-stop-patterns.md) need agent name references removed from the core and added to the extension's index-entries.json instead

## Context & Scope

This task involves moving neovim-specific elements from the core locations of both the .claude/ and .opencode/ agent systems into `nvim/` extension directories. Both systems share the same extension architecture pattern (manifest.json, EXTENSION.md, index-entries.json, agents/, skills/, context/, rules/) but have structural differences that must be respected.

## Findings

### 1. Neovim Elements to Move - .claude/ System

#### Agents (2 files)
- `.claude/agents/neovim-research-agent.md` -> `.claude/extensions/nvim/agents/neovim-research-agent.md`
- `.claude/agents/neovim-implementation-agent.md` -> `.claude/extensions/nvim/agents/neovim-implementation-agent.md`

#### Skills (2 directories)
- `.claude/skills/skill-neovim-research/SKILL.md` -> `.claude/extensions/nvim/skills/skill-neovim-research/SKILL.md`
- `.claude/skills/skill-neovim-implementation/SKILL.md` -> `.claude/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`

#### Context Files (16 files)
- Entire directory: `.claude/context/project/neovim/` -> `.claude/extensions/nvim/context/project/neovim/`
- Subdirectories: domain/ (4 files), patterns/ (4 files), standards/ (2 files), templates/ (2 files), tools/ (3 files), plus README.md

#### Rules (1 file)
- `.claude/rules/neovim-lua.md` -> `.claude/extensions/nvim/rules/neovim-lua.md`

### 2. Neovim Elements to Move - .opencode/ System

#### Agents (2 files)
- `.opencode/agent/subagents/neovim-research-agent.md` -> `.opencode/extensions/nvim/agents/neovim-research-agent.md`
- `.opencode/agent/subagents/neovim-implementation-agent.md` -> `.opencode/extensions/nvim/agents/neovim-implementation-agent.md`

#### Skills (2 directories)
- `.opencode/skills/skill-neovim-research/SKILL.md` -> `.opencode/extensions/nvim/skills/skill-neovim-research/SKILL.md`
- `.opencode/skills/skill-neovim-implementation/SKILL.md` -> `.opencode/extensions/nvim/skills/skill-neovim-implementation/SKILL.md`

#### Context Files (22 files, including READMEs)
- Entire directory: `.opencode/context/project/neovim/` -> `.opencode/extensions/nvim/context/project/neovim/`
- Note: .opencode has README.md in each subdirectory (domain/, patterns/, standards/, templates/, tools/) plus a stray `lua-patterns.md` at the neovim/ root level
- Total: 22 files vs 16 in .claude (6 extra READMEs + 1 extra lua-patterns.md at root)

#### Rules (1 file)
- `.opencode/rules/neovim-lua.md` -> `.opencode/extensions/nvim/rules/neovim-lua.md`

### 3. Extension Structure Pattern

Based on analysis of existing extensions (z3, latex, nix, web, etc.), the nvim extension needs:

#### Required Files

**manifest.json** - Extension metadata and wiring declaration:
```json
{
  "name": "nvim",
  "version": "1.0.0",
  "description": "Neovim configuration development with lazy.nvim and Lua",
  "language": "neovim",
  "dependencies": [],
  "provides": {
    "agents": ["neovim-research-agent.md", "neovim-implementation-agent.md"],
    "skills": ["skill-neovim-research", "skill-neovim-implementation"],
    "commands": [],
    "rules": ["neovim-lua.md"],
    "context": ["project/neovim"],
    "scripts": [],
    "hooks": []
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_nvim"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  },
  "mcp_servers": {}
}
```

For .opencode, the `merge_targets` key changes:
```json
"merge_targets": {
  "opencode_md": {
    "source": "EXTENSION.md",
    "target": ".opencode/OPENCODE.md",
    "section_id": "extension_oc_nvim"
  },
  "index": {
    "source": "index-entries.json",
    "target": ".opencode/context/index.json"
  }
}
```

**EXTENSION.md** - Content to merge into CLAUDE.md/README.md (routing table, skill-agent mapping, context references)

**index-entries.json** - Context discovery entries for neovim language/agents

### 4. Wiring Points That Need Updating

#### 4a. Command Routing Tables

**.claude/commands/research.md** (line 52):
- Currently lists `neovim | skill-neovim-research` in routing table
- After move: This still works because Claude Code discovers extension skills automatically
- However, for clarity, the routing table comment should note it's from the nvim extension

**.claude/commands/implement.md** (line 67):
- Same pattern as above for `neovim | skill-neovim-implementation`

**.opencode/commands/research.md** (line 104):
- Same: `neovim | skill-neovim-research`

**.opencode/commands/implement.md** (lines 84, 114, 162, 176):
- Multiple neovim references in routing table and validation

#### 4b. CLAUDE.md Updates

**.claude/CLAUDE.md** - Multiple neovim references need updating:
- Line 56: Language routing table (neovim row)
- Line 106: state.json example using `"language": "neovim"`
- Lines 138-139: Skill-to-agent mapping table (neovim entries)
- Line 156: Rules reference to `neovim-lua.md`
- Lines 167, 170: Context discovery examples using neovim
- Lines 181-183: Context imports for neovim

After moving, the neovim routing entry should remain in the routing table (since extensions add languages), but the agent/skill mapping and context imports should move to the EXTENSION.md that gets merged in. The rules reference should update the path.

#### 4c. .opencode/README.md Updates

Similar changes needed:
- Line 47: Language routing table
- Lines 194-195: Skill-agent mapping
- Line 223: Rules reference
- Lines 232-234: Context references

#### 4d. Orchestration Core (.opencode)

**.opencode/context/core/orchestration/orchestration-core.md**:
- Lines 184, 186: Neovim appears in the routing table alongside extension languages
- Lines 220-223: Neovim has its OWN routing validation block (separate from extension loop at 226-233)
- **Decision required**: Should neovim validation move to the extension validation loop, or stay as a core validation? Recommendation: Move to extension loop for consistency with other extensions.

#### 4e. Index.json Updates

**Core entries referencing neovim agents** (both .claude and .opencode):
- `core/formats/return-metadata-file.md` - lists `neovim-implementation-agent` in agents array
- `core/patterns/anti-stop-patterns.md` - lists `neovim-implementation-agent` in agents array
- These need `neovim-implementation-agent` removed from their agents arrays (the extension's index-entries.json will provide the agent-to-context mapping instead)

**Neovim-specific entries to remove from core index.json** (both systems):
- `project/neovim/README.md` entry
- `project/neovim/patterns/plugin-spec.md` entry
- These move to the extension's index-entries.json

**Extension index-entries.json must include**:
- All context files from the neovim directory with appropriate language/agent mappings
- These should follow the pattern established by z3/latex extensions

### 5. Structural Differences Between .claude/ and .opencode/

| Aspect | .claude/ | .opencode/ |
|--------|----------|------------|
| Agent location | `.claude/agents/` | `.opencode/agent/subagents/` |
| Extension agents | `extensions/{ext}/agents/` | `extensions/{ext}/agents/` |
| README files | No subdirectory READMEs in context | README.md at every directory level |
| Context files | 16 files | 22 files (6 extra READMEs + 1 extra lua-patterns.md) |
| Merge target key | `claudemd` | `opencode_md` |
| Merge target file | `.claude/CLAUDE.md` | `.opencode/OPENCODE.md` |
| Section ID prefix | `extension_` | `extension_oc_` |
| Rules location | `.claude/rules/` | `.opencode/rules/` |
| Skills location | `.claude/skills/` | `.opencode/skills/` |

### 6. Rules File Consideration

The `.claude/rules/neovim-lua.md` (and `.opencode/rules/neovim-lua.md`) uses a path pattern:
```
Applies to: `lua/**/*.lua`, `after/**/*.lua`
```

This is a glob pattern that Claude Code applies automatically when editing files matching the pattern. When moved to the extension, this should still work because:
- The `.claude/rules/` reference in CLAUDE.md will need updating to point to the extension path
- OR the extension's `provides.rules` field handles the discovery automatically

The existing extensions with rules (e.g., latex) use `"rules": ["latex.md"]` in their manifest, so the same pattern applies.

## Decisions

1. **Extension name**: `nvim` (matching the directory convention of short names like z3, nix, web)
2. **Language value**: `neovim` (matching existing state.json and routing table values)
3. **Move vs copy**: Move (delete originals) to avoid confusion about which is canonical
4. **Routing table entries**: Keep neovim in command routing tables (commands need to know which skill to invoke), but mark as extension-provided
5. **Core index.json**: Remove neovim-specific entries and neovim agent references from core entries; extension's index-entries.json provides these
6. **Orchestration validation**: Move neovim routing validation into the extension loop alongside other extension languages

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking existing neovim task routing | High | Verify all routing tables are updated, test with dry run |
| Missing context file references | Medium | Compare file counts before/after move |
| .opencode OPENCODE.md doesn't exist yet | Low | Extensions declare the target; if file doesn't exist, merge is a no-op |
| Rule path pattern stops working | Medium | Verify extension rule discovery mechanism; test with nvim --headless |
| Extra .opencode lua-patterns.md at neovim root | Low | Include in move; it's a stray file that should go with the rest |

## Appendix

### File Counts

| Category | .claude/ | .opencode/ |
|----------|----------|------------|
| Agents | 2 | 2 |
| Skills | 2 (directories) | 2 (directories) |
| Context files | 16 | 22 |
| Rules | 1 | 1 |
| **Total** | **21** | **27** |

### Search Queries Used
- `find .claude/agents -name "*neovim*"`
- `find .claude/context/project/neovim -type f`
- `grep -rn "neovim" .claude/CLAUDE.md`
- `grep -rn "skill-neovim" .opencode/`
- `jq` queries on index.json for neovim language/agent entries
- Comparison of extension structures (z3, latex) for pattern reference

### Reference Extension Structures Examined
- `.claude/extensions/z3/` - Minimal extension (no rules, no README subdirs)
- `.claude/extensions/latex/` - Full extension (rules, context subdirs)
- `.opencode/extensions/z3/` - Minimal with README.md at every level
- `.opencode/extensions/latex/` - Full with README.md at every level
