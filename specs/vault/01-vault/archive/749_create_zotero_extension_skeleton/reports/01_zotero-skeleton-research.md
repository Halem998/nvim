# Research Report: Task #749

**Task**: 749 — Create Zotero Extension Skeleton
**Started**: 2026-06-19T00:00:00Z
**Completed**: 2026-06-19T00:30:00Z
**Effort**: 1 phase
**Dependencies**: Task 748 architecture design (complete)
**Sources/Inputs**: Codebase (literature extension, install-extension.sh, existing index-entries.json patterns), Task 748 summary doc
**Artifacts**: specs/749_create_zotero_extension_skeleton/reports/01_zotero-skeleton-research.md
**Standards**: report-format.md

---

## Executive Summary

- The literature extension is the correct template: `routing_exempt: true`, provides block with agents/commands/skills/scripts, EXTENSION.md merge target, no `index-entries.json` (literature is the only extension missing one — the zotero extension should include one)
- The task 748 architecture design at `specs/748_design_zotero_extension_architecture/summaries/01_zotero-arch-design.md` is a complete, detailed specification covering the exact `manifest.json` content, directory layout, script architecture, command surface, and per-repo index schema
- The extension loader (`install-extension.sh`) creates symlinks for commands, skills, and agents, and merges `index-entries.json` into `.claude/context/index.json`; the zotero extension needs its own `index-entries.json` for the two context files under `context/project/zotero/`
- Task 749 scope is skeleton-only: manifest.json, EXTENSION.md, README.md, index-entries.json, stub agents/commands/skills/SKILL.md, empty script placeholders, and context file stubs — no script implementation

---

## Context & Scope

### What Was Researched

1. The complete file tree and content of the literature extension (the authoritative template)
2. The task 748 architecture design document (the authoritative specification for the zotero extension)
3. The extension loader mechanism (`install-extension.sh`, `uninstall-extension.sh`)
4. The `index-entries.json` format as used by other extensions (memory, nix, z3, python)
5. How `merge_targets.index` in manifest.json maps to `index-entries.json`

### Constraints

- Task 749 creates the skeleton only; scripts are stubs (not implemented)
- Context files under `context/project/zotero/` are stubs (headers only, content added in later tasks)
- The skeleton must load without errors in the extension picker — this means manifest.json must be valid JSON and all referenced files must exist

---

## Findings

### Codebase Patterns

#### Literature Extension File Tree (Template)

```
.claude/extensions/literature/
├── manifest.json             # Extension metadata: routing_exempt, provides, merge_targets
├── EXTENSION.md              # Merged into .claude/CLAUDE.md under section_id
├── README.md                 # Human-facing setup and usage guide
├── agents/
│   └── literature-agent.md  # Direct execution agent (documentation + architecture diagram)
├── commands/
│   ├── literature.md         # /literature command (argument parsing + dispatch)
│   └── cite.md               # /cite command
├── skills/
│   ├── skill-literature/
│   │   └── SKILL.md          # All implementation logic for literature modes
│   └── skill-cite/
│       └── SKILL.md          # Citation verification implementation
└── scripts/
    ├── zotero-search.sh      # CSL-JSON search script
    └── cite-extract.sh       # Citation pattern extraction script
```

Note: literature has NO `index-entries.json`. Every other extension does. The zotero extension needs one for its two context files.

#### manifest.json Structure (Literature)

```json
{
  "name": "literature",
  "version": "1.0.0",
  "description": "...",
  "dependencies": ["core", "filetypes"],
  "routing_exempt": true,
  "provides": {
    "agents": ["literature-agent.md"],
    "commands": ["literature.md", "cite.md"],
    "skills": ["skill-literature", "skill-cite"],
    "scripts": ["scripts/zotero-search.sh", "scripts/cite-extract.sh"]
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_literature"
    }
  },
  "hooks": {}
}
```

Note: literature does NOT have `merge_targets.index`. The zotero extension's manifest specifies `merge_targets.index` pointing to `index-entries.json`. This is the mechanism by which `install-extension.sh` merges context entries.

#### EXTENSION.md Pattern (Literature Template)

The EXTENSION.md for literature starts with `## Literature Extension` (level-2 heading matching the section_id). It contains:
- A descriptive paragraph
- A "Centralized Repository" section with usage pattern
- "Key Conventions" for storage layout
- "Skill-Agent Mapping" table
- "Commands" table listing all commands with usage and description
- A second command section for /cite

For zotero, the EXTENSION.md should follow this same pattern under `## Zotero Extension`.

#### Agent File Pattern (Literature)

The literature-agent.md uses:
- YAML frontmatter: `name`, `description`, `model: sonnet`, `allowed-tools`
- `# Literature Agent` level-1 heading
- `## Overview` section explaining it's documentation-only for a direct-execution skill
- `## Execution Pattern` showing the full invocation tree as an ASCII diagram
- Detailed architecture notes for each mode

For zotero, the zotero-agent.md should follow this same documentation-agent pattern.

#### Command File Pattern (Literature)

The literature.md command file uses:
- YAML frontmatter: `description`, `allowed-tools: Skill`, `argument-hint`
- `# Command: /literature` level-1 heading
- `**Purpose**`, `**Layer**: 2`, `**Delegates To**: skill-literature`
- `## Argument Parsing` section with XML-like `<argument_parsing>` block
- `## Workflow Execution` with `<step_N>` blocks
- `## Error Handling` with `<argument_errors>` and `<execution_errors>`
- `## State Management` with `<reads>` and `<writes>` lists

For zotero, the command should similarly parse the 12 sub-modes from the architecture design.

#### SKILL.md Pattern (Literature)

The skill-literature SKILL.md uses:
- YAML frontmatter: `name`, `description`, `allowed-tools`
- `# Literature Skill (Direct Execution)` heading with key behavior summary
- `## Context References` (lazy-loaded)
- `## Execution` with numbered steps
- Individual `## Mode: {ModeName}` sections with per-step bash pseudocode

For zotero's skeleton SKILL.md, the structure should be present with mode stubs (not full implementations since scripts don't exist yet).

#### index-entries.json Pattern (Memory Extension as Model)

The memory extension's `index-entries.json` uses the object-with-entries array format:

```json
{
  "entries": [
    {
      "path": "project/memory/learn-usage.md",
      "domain": "project",
      "subdomain": "memory",
      "topics": ["memory", "learn"],
      "keywords": ["learn", "memory", "vault"],
      "summary": "Usage guide for /learn command",
      "line_count": 150,
      "load_when": {
        "skills": ["skill-memory"],
        "commands": ["/learn"]
      }
    }
  ]
}
```

The `install-extension.sh` handles both flat array format (nix, web) and object-with-entries format (z3, python, formal). The zotero extension should use the object-with-entries format, matching memory.

The two context files from the architecture spec are:
1. `project/zotero/domain/zotero-index.md` — index schema + workflow
2. `project/zotero/patterns/retrieval-flags.md` — when to use --zot vs --lit

These map to two entries in `index-entries.json`, loaded when `skill-zotero` is active and when `/zotero` command is invoked.

#### Extension Loader Mechanism

`install-extension.sh` performs four operations:
1. `install_commands()` — Creates symlinks `.claude/commands/{name}.md -> ../extensions/zotero/commands/{name}.md`
2. `install_skills()` — Creates symlinks `.claude/skills/skill-zotero -> ../extensions/zotero/skills/skill-zotero`
3. `install_agents()` — Creates symlinks `.claude/agents/zotero-agent.md -> ../extensions/zotero/agents/zotero-agent.md`
4. `merge_index_entries()` — Reads `index-entries.json`, merges entries into `.claude/context/index.json`

The loader also handles `provides.scripts` by copying scripts to `.claude/scripts/`. For the skeleton, the scripts directory should have 9 stub files (non-executable or minimal stubs) matching the names in `provides.scripts`.

The extension is picked via the extension picker UI (referenced in CLAUDE.md). The picker reads `manifest.json` from `extensions/*/` directories.

### Task 748 Architecture Specification

The architecture design provides precise specifications for all skeleton files:

#### manifest.json (from Section 2)

```json
{
  "name": "zotero",
  "version": "1.0.0",
  "description": "Zotero library integration via zot (zotero-cli-cc v0.7.0). Two-tier model: Zotero SQLite as global source, per-repo specs/zotero-index.json as relevance filter. Provides /zotero command and --zot context injection flag.",
  "dependencies": ["core", "literature"],
  "routing_exempt": true,
  "provides": {
    "agents": ["zotero-agent.md"],
    "commands": ["zotero.md"],
    "skills": ["skill-zotero"],
    "scripts": [
      "scripts/zotero-read.sh",
      "scripts/zotero-write.sh",
      "scripts/zotero-setup.sh",
      "scripts/zotero-chunk.sh",
      "scripts/zotero-attach-chunks.sh",
      "scripts/zotero-index-add.sh",
      "scripts/zotero-index-remove.sh",
      "scripts/zotero-retrieve.sh",
      "scripts/zotero-search-index.sh"
    ],
    "context": ["project/zotero"],
    "rules": [],
    "hooks": []
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_zotero"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  },
  "keyword_overrides": {
    "zotero": "meta",
    "bibliography": "meta",
    "citation": "meta"
  },
  "hooks": {}
}
```

#### Directory Layout (from Section 3)

The full target directory structure including all 9 script stubs and 2 context files.

#### Command Surface (from Section 7)

12 sub-modes for the `/zotero` command:
- (bare), --setup, --add KEY, --add KEY --chunk, --remove KEY, --remove KEY --delete-chunks, --convert KEY, --attach KEY, --search QUERY, --sync, --validate, --status

#### Script Architecture (from Section 5)

9 scripts organized in 4 categories:
- Category A (CLI Wrappers): zotero-read.sh, zotero-write.sh, zotero-setup.sh
- Category B (Chunk Management): zotero-chunk.sh, zotero-attach-chunks.sh, zotero-index-add.sh
- Category C (Index Management): zotero-index-remove.sh, zotero-search-index.sh
- Category D (Context Injection): zotero-retrieve.sh

Note: The architecture design groups `zotero-index-add.sh` under Category B, but it logically also serves Category C. The manifest lists it separately from `zotero-index-remove.sh` and `zotero-search-index.sh`.

### Recommendations

#### 1. Manifest.json

Use the exact content from Section 2 of the architecture design. One clarification: the `provides.scripts` list in the manifest uses paths with `scripts/` prefix, but the install script strips the prefix when creating symlinks. Use the paths-with-prefix format exactly as specified.

#### 2. EXTENSION.md

Follow literature EXTENSION.md structure but adapted for zotero:
- Section heading: `## Zotero Extension`
- Describe the two-tier model (Zotero SQLite + per-repo index)
- Show the `--zot` flag usage for context injection
- Include Skill-Agent Mapping table (single row: skill-zotero / direct execution)
- Include Commands table: `/zotero` with all 12 sub-mode variations

#### 3. README.md

Include:
- Installation prerequisites (`zot` / zotero-cli-cc v0.7.0)
- Quick start: `/zotero --setup`
- Common workflows: add item, search, convert PDF, use --zot flag
- Graceful degradation notes (what works without `zot` installed)

#### 4. index-entries.json

Two entries using the object-with-entries format:
- `project/zotero/domain/zotero-index.md` — loaded when skill-zotero is active
- `project/zotero/patterns/retrieval-flags.md` — loaded when skill-zotero or /zotero command is active

#### 5. zotero-agent.md

Document-only agent (like literature-agent.md). Include:
- YAML frontmatter with `model: sonnet`, `allowed-tools: Bash, Read, Write, Edit, AskUserQuestion`
- Architecture diagram showing the full invocation tree for all 12 sub-modes
- Note that this is direct execution (no subagent spawned)

#### 6. commands/zotero.md

Follow literature.md pattern with:
- `allowed-tools: Skill`
- Argument parsing for all 12 sub-modes
- Dispatch to skill-zotero with mode and KEY/QUERY args

#### 7. skills/skill-zotero/SKILL.md

Skeleton with:
- Mode dispatch `case` statement for all 12 sub-modes
- Mode handler stubs (step 1: parse args, step 2: call script, step 3: display result)
- The skill is "direct execution" — no subagent spawned
- Note: Full script implementations come in tasks 750-753; stubs just need to document the intended behavior and show the script call pattern

#### 8. scripts/ Stubs

9 stub scripts, each with:
```bash
#!/usr/bin/env bash
# {script-name}.sh — {brief description from Section 5}
# Implementation: Task {750|751|752|753}
set -euo pipefail
echo "Not yet implemented. See task {N}." >&2
exit 2
```

Using exit code 2 (not configured) rather than 1 (error) ensures callers like `zotero-retrieve.sh` gracefully degrade rather than treating this as a hard error.

#### 9. context/project/zotero/ Stubs

Two stub markdown files:
- `domain/zotero-index.md` — placeholder header + "Content populated in task 751"
- `patterns/retrieval-flags.md` — placeholder header + "Content populated in task 753"

### Key Differences: Zotero vs Literature Extension

| Aspect | Literature | Zotero |
|--------|-----------|--------|
| `routing_exempt` | true | true |
| `dependencies` | core, filetypes | core, literature |
| `index-entries.json` | MISSING (anomaly) | Required (follow all other extensions) |
| `merge_targets.index` | absent | present (points to index-entries.json) |
| `keyword_overrides` | absent | present (zotero, bibliography, citation -> meta) |
| Number of commands | 2 (literature, cite) | 1 (zotero) |
| Number of skills | 2 (skill-literature, skill-cite) | 1 (skill-zotero) |
| Number of scripts | 2 | 9 |
| Context files | 0 | 2 |
| Agent purpose | Documentation-only (direct execution) | Documentation-only (direct execution) |

---

## Decisions

1. **Script stubs use exit 2**: Stubs exit with code 2 (not configured) not 1 (error), because `zotero-retrieve.sh` interprets exit 2 as graceful absence and emits empty context rather than a hard failure
2. **index-entries.json required**: Despite literature not having one, the zotero extension must include one — literature is an anomaly; all other extensions follow the pattern
3. **No `provides.context` in install-extension.sh**: The `provides.context` field in manifest.json is noted but `install-extension.sh` doesn't process it (it handles commands, skills, agents, index-entries). Context files are read directly from the extension's own `context/` directory tree. The paths in index-entries.json are relative to `.claude/context/` so they must physically exist there. However, based on the nix extension pattern, context files in `extensions/*/context/project/X/` are accessed directly via paths in index-entries.json that resolve to the extension tree. Need to verify this path convention.
4. **Content stub approach**: Context files get headers + "populated in task N" notes, not empty files (empty files might cause issues with index entry line_count validation)

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Script stubs blocking graceful degradation | Medium | Use exit 2 (not configured) not exit 1 (error) in all stubs |
| Extension picker failing to load if files missing | High | All files referenced in manifest.json must physically exist before installing |
| Context file path resolution unclear | Medium | Check how other extensions expose their context/ to the index; paths in index-entries.json must resolve correctly relative to the CLAUDE.md context loader |
| index-entries.json paths must match physical files | High | The context files under context/project/zotero/ must exist at the paths declared in index-entries.json |
| `provides.scripts` not handled by install-extension.sh | Low | install-extension.sh handles commands/skills/agents/index only; scripts may need to be manually symlinked or this field is informational only |

### Context File Path Resolution Clarification Needed

The `install-extension.sh` does not process `provides.context`. The index-entries.json entries reference paths like `project/zotero/domain/zotero-index.md`. In the main context index, these paths are relative to `.claude/context/`. So the files must exist at `.claude/context/project/zotero/domain/zotero-index.md`.

Looking at the nix extension: `index-entries.json` references `project/nix/README.md` with no prefix. These files physically exist at `.claude/extensions/nix/context/project/nix/README.md`. The extension loader maps extension context paths to the extension directory, not to the main `.claude/context/` directory. This means:
- Context stubs go in: `.claude/extensions/zotero/context/project/zotero/domain/zotero-index.md`
- Index entry path: `project/zotero/domain/zotero-index.md`
- The loader resolves this as `extensions/zotero/context/project/zotero/domain/zotero-index.md`

This matches the architecture design's directory layout exactly (Section 3 shows `context/project/zotero/` under the extension directory).

---

## Context Extension Recommendations

The task 748 design already documents context file content targets for `project/zotero/domain/zotero-index.md` (index schema + workflow) and `project/zotero/patterns/retrieval-flags.md` (when to use --zot vs --lit). These will be populated in tasks 751 and 753 respectively. No additional context documentation gap exists.

---

## Complete File Inventory for Implementation

The following files must be created by task 749:

```
.claude/extensions/zotero/
├── manifest.json                       (from Section 2 spec — exact content)
├── EXTENSION.md                        (literature template adapted for zotero)
├── README.md                           (human setup guide)
├── index-entries.json                  (2 entries: zotero-index.md + retrieval-flags.md)
├── agents/
│   └── zotero-agent.md                (documentation agent with architecture diagram)
├── commands/
│   └── zotero.md                      (argument parsing for 12 sub-modes)
├── skills/
│   └── skill-zotero/
│       └── SKILL.md                   (direct execution skill with mode stubs)
├── scripts/
│   ├── zotero-read.sh                 (stub, exit 2)
│   ├── zotero-write.sh                (stub, exit 2)
│   ├── zotero-setup.sh                (stub, exit 2)
│   ├── zotero-chunk.sh                (stub, exit 2)
│   ├── zotero-attach-chunks.sh        (stub, exit 2)
│   ├── zotero-index-add.sh            (stub, exit 2)
│   ├── zotero-index-remove.sh         (stub, exit 2)
│   ├── zotero-retrieve.sh             (stub, exit 2)
│   └── zotero-search-index.sh         (stub, exit 2)
└── context/
    └── project/
        └── zotero/
            ├── domain/
            │   └── zotero-index.md    (stub with header + Section 4 schema summary)
            └── patterns/
                └── retrieval-flags.md (stub with header + Section 9 coexistence table)
```

**Total**: 17 files to create

---

## Appendix

### Search Queries Used
- Codebase: `find .claude/extensions/literature -type f`
- Codebase: `find .claude/extensions -name "index-entries.json"`
- Codebase: `cat .claude/scripts/install-extension.sh`
- Codebase: `cat .claude/extensions/memory/index-entries.json`
- Codebase: `cat .claude/extensions/nix/index-entries.json`
- Codebase: `cat specs/748_design_zotero_extension_architecture/summaries/01_zotero-arch-design.md`

### Key References
- Task 748 architecture design: `specs/748_design_zotero_extension_architecture/summaries/01_zotero-arch-design.md`
- Literature extension (template): `.claude/extensions/literature/`
- Extension installer: `.claude/scripts/install-extension.sh`
- Memory extension index-entries.json (model for format): `.claude/extensions/memory/index-entries.json`
