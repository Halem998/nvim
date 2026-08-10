# Implementation Plan: Task #749

- **Task**: 749 - Create Zotero Extension Skeleton
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: Task 748 architecture design (complete)
- **Research Inputs**: specs/749_create_zotero_extension_skeleton/reports/01_zotero-skeleton-research.md
- **Artifacts**: plans/01_zotero-skeleton-plan.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create the complete extension scaffold for the zotero extension at `.claude/extensions/zotero/`. This involves creating 17 files: core extension metadata (manifest.json, EXTENSION.md, README.md, index-entries.json), command/skill/agent definitions, 9 script stubs with exit code 2 for graceful degradation, and 2 context file stubs. The final step wires the extension into the loader via `install-extension.sh`. All content is derived from the task 748 architecture design and the literature extension template.

### Research Integration

The research report (01_zotero-skeleton-research.md) confirmed:
- Literature extension at `.claude/extensions/literature/` is the authoritative template for file structure and patterns
- Task 748 architecture design provides exact manifest.json content, directory layout, script names, and command surface
- Script stubs must use exit code 2 (not configured) for graceful degradation
- Extension needs `index-entries.json` (literature is the only extension missing one)
- `install-extension.sh` creates symlinks for commands/skills/agents and merges index entries
- Context files reside under `extensions/zotero/context/project/zotero/` and index-entries.json paths reference them relative to `.claude/context/`

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap items directly match this task. The extension scaffold supports the broader "Literature centralization" work (Phase 2, already completed) by adding Zotero-specific infrastructure that complements the literature extension.

## Goals & Non-Goals

**Goals**:
- Create complete `.claude/extensions/zotero/` directory tree with all 17 files
- Ensure extension loads without errors in the extension picker
- All script stubs exit with code 2 (not configured) for graceful degradation
- Wire extension into loader via `install-extension.sh`

**Non-Goals**:
- Implement actual script logic (deferred to tasks 750-753)
- Populate context files with full content (stubs only; populated in tasks 751, 753)
- Modify `command-route-skill.sh` for `--zot` flag (task 753)
- Create `specs/zotero-index.json` (created at runtime by `/zotero --setup`)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Extension picker fails to load if referenced files missing | H | L | All files in manifest.json `provides` are created before running install-extension.sh |
| Context file path resolution mismatch between index-entries.json and physical location | M | M | Follow nix extension pattern exactly: files at `extensions/zotero/context/project/zotero/`, index paths relative to `.claude/context/` |
| Script stubs not executable | L | M | Set chmod +x on all script stubs during creation |
| install-extension.sh fails on new extension | M | L | Verify extension loads by checking symlink creation and index merge output |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Core Extension Files [COMPLETED]

**Goal**: Create the extension directory and the 4 core metadata files that define the extension identity and context integration.

**Tasks**:
- [x] Create directory tree: `.claude/extensions/zotero/{agents,commands,skills/skill-zotero,scripts,context/project/zotero/domain,context/project/zotero/patterns}` *(completed)*
- [x] Write `manifest.json` using exact content from task 748 Section 2 specification *(completed)*
- [x] Write `EXTENSION.md` following literature EXTENSION.md structure, adapted for zotero: `## Zotero Extension` heading, two-tier model description, `--zot` flag usage, Skill-Agent Mapping table (skill-zotero / direct execution), Commands table with all 12 sub-modes *(completed)*
- [x] Write `README.md` with: installation prerequisites (`zot` / zotero-cli-cc v0.7.0), quick start (`/zotero --setup`), common workflows (add item, search, convert PDF, use --zot flag), graceful degradation notes *(completed)*
- [x] Write `index-entries.json` with 2 entries using object-with-entries format: `project/zotero/domain/zotero-index.md` (loaded for skill-zotero) and `project/zotero/patterns/retrieval-flags.md` (loaded for skill-zotero and /zotero command) *(completed)*

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/zotero/manifest.json` - Create with exact Section 2 spec content
- `.claude/extensions/zotero/EXTENSION.md` - Create following literature template pattern
- `.claude/extensions/zotero/README.md` - Create with setup and usage guide
- `.claude/extensions/zotero/index-entries.json` - Create with 2 context entries

**Verification**:
- `manifest.json` is valid JSON (test with `jq . manifest.json`)
- `index-entries.json` is valid JSON with exactly 2 entries
- All directories in the tree exist
- `EXTENSION.md` starts with `## Zotero Extension` heading

---

### Phase 2: Command and Skill Definitions [COMPLETED]

**Goal**: Create the `/zotero` command file and the `skill-zotero` SKILL.md that defines the direct-execution skill with all 12 sub-mode stubs.

**Tasks**:
- [x] Write `commands/zotero.md` following literature.md command pattern: YAML frontmatter (`description`, `allowed-tools: Skill`, `argument-hint`), argument parsing for all 12 sub-modes (bare, --setup, --add KEY, --add KEY --chunk, --remove KEY, --remove KEY --delete-chunks, --convert KEY, --attach KEY, --search QUERY, --sync, --validate, --status), dispatch to skill-zotero *(completed)*
- [x] Write `skills/skill-zotero/SKILL.md` following literature SKILL.md pattern: YAML frontmatter (`name`, `description`, `allowed-tools`), direct execution heading, context references, mode dispatch case statement for all 12 sub-modes, mode handler stubs documenting intended behavior and script call pattern *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/zotero/commands/zotero.md` - Create command definition
- `.claude/extensions/zotero/skills/skill-zotero/SKILL.md` - Create skill definition

**Verification**:
- `commands/zotero.md` has valid YAML frontmatter
- `SKILL.md` references all 12 sub-modes
- Both files follow the naming patterns from the literature extension

---

### Phase 3: Agent Definition [COMPLETED]

**Goal**: Create the documentation-only agent file that describes the zotero extension architecture and invocation tree.

**Tasks**:
- [x] Write `agents/zotero-agent.md` following literature-agent.md pattern: YAML frontmatter (`name: zotero-agent`, `description`, `model: sonnet`, `allowed-tools: Bash, Read, Write, Edit, AskUserQuestion`), `# Zotero Agent` heading, `## Overview` explaining documentation-only agent for direct-execution skill, `## Execution Pattern` with ASCII architecture diagram showing invocation tree for all 12 sub-modes and their script dispatches *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/zotero/agents/zotero-agent.md` - Create agent definition

**Verification**:
- Agent file has valid YAML frontmatter with `model: sonnet`
- Contains architecture diagram showing command -> skill -> script dispatch

---

### Phase 4: Script Stubs and Context Files [COMPLETED]

**Goal**: Create all 9 script stubs with exit code 2 and both context file stubs.

**Tasks**:
- [x] Create 9 script stubs in `scripts/`, each with: bash shebang, brief description comment, implementation task reference, `set -euo pipefail`, stderr message, `exit 2`. Scripts: `zotero-read.sh`, `zotero-write.sh`, `zotero-setup.sh`, `zotero-chunk.sh`, `zotero-attach-chunks.sh`, `zotero-index-add.sh`, `zotero-index-remove.sh`, `zotero-retrieve.sh`, `zotero-search-index.sh` *(completed)*
- [x] Set executable permissions on all 9 scripts (`chmod +x`) *(completed)*
- [x] Create `context/project/zotero/domain/zotero-index.md` stub with header and "Content populated in task 751" note, including brief Section 4 schema summary placeholder *(completed)*
- [x] Create `context/project/zotero/patterns/retrieval-flags.md` stub with header and "Content populated in task 753" note, including brief Section 9 coexistence table placeholder *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/zotero/scripts/zotero-read.sh` - Create stub (Category A, task 750)
- `.claude/extensions/zotero/scripts/zotero-write.sh` - Create stub (Category A, task 750)
- `.claude/extensions/zotero/scripts/zotero-setup.sh` - Create stub (Category A, task 750)
- `.claude/extensions/zotero/scripts/zotero-chunk.sh` - Create stub (Category B, task 752)
- `.claude/extensions/zotero/scripts/zotero-attach-chunks.sh` - Create stub (Category B, task 752)
- `.claude/extensions/zotero/scripts/zotero-index-add.sh` - Create stub (Category B/C, task 751)
- `.claude/extensions/zotero/scripts/zotero-index-remove.sh` - Create stub (Category C, task 751)
- `.claude/extensions/zotero/scripts/zotero-retrieve.sh` - Create stub (Category D, task 753)
- `.claude/extensions/zotero/scripts/zotero-search-index.sh` - Create stub (Category C, task 751)
- `.claude/extensions/zotero/context/project/zotero/domain/zotero-index.md` - Create stub
- `.claude/extensions/zotero/context/project/zotero/patterns/retrieval-flags.md` - Create stub

**Verification**:
- All 9 scripts exist and are executable (`ls -la scripts/`)
- Each script exits with code 2 when run (`bash scripts/zotero-read.sh; echo $?` returns 2)
- Both context files exist with non-empty content

---

### Phase 5: Extension Loader Wiring and Verification [COMPLETED]

**Goal**: Wire the zotero extension into the extension loader and verify the complete skeleton loads correctly.

**Tasks**:
- [x] Run `bash .claude/scripts/install-extension.sh zotero` to create symlinks and merge index entries *(completed)*
- [x] Verify symlinks created: `.claude/commands/zotero.md`, `.claude/skills/skill-zotero`, `.claude/agents/zotero-agent.md` *(completed)*
- [x] Verify `index-entries.json` entries merged into `.claude/context/index.json` *(completed)*
- [x] Verify `EXTENSION.md` content merged into `.claude/CLAUDE.md` under `extension_zotero` section *(completed: added Zotero Extension section manually)*
- [x] Run `jq . .claude/extensions/zotero/manifest.json` to confirm valid JSON *(completed)*
- [x] Run `jq '.entries | length' .claude/extensions/zotero/index-entries.json` to confirm 2 entries *(completed)*
- [x] Verify all 17 files exist with a find command *(completed: 18 files — plan undercounted SKILL.md)*

**Timing**: 15 minutes

**Depends on**: 1, 2, 3, 4

**Files to modify**:
- `.claude/context/index.json` - Modified by install-extension.sh (index merge)
- `.claude/CLAUDE.md` - Modified by install-extension.sh (EXTENSION.md merge)

**Verification**:
- Symlinks resolve correctly (`readlink -f .claude/commands/zotero.md` points to extension)
- `index.json` contains zotero context entries
- `CLAUDE.md` contains Zotero Extension section
- `find .claude/extensions/zotero -type f | wc -l` returns 17

## Testing & Validation

- [ ] `manifest.json` passes JSON validation (`jq . manifest.json`)
- [ ] `index-entries.json` passes JSON validation with 2 entries
- [ ] All 9 script stubs exit with code 2
- [ ] All 9 script stubs are executable
- [ ] Both context files are non-empty
- [ ] Extension loads via `install-extension.sh` without errors
- [ ] Symlinks created for command, skill, and agent
- [ ] Index entries merged into `.claude/context/index.json`
- [ ] Total file count is 17 (`find .claude/extensions/zotero -type f | wc -l`)

## Artifacts & Outputs

- `specs/749_create_zotero_extension_skeleton/plans/01_zotero-skeleton-plan.md` (this plan)
- `.claude/extensions/zotero/` directory tree with 17 files
- Updated `.claude/context/index.json` with zotero entries
- Updated `.claude/CLAUDE.md` with Zotero Extension section

## Rollback/Contingency

To revert: remove the extension directory and uninstall symlinks.
```bash
bash .claude/scripts/uninstall-extension.sh zotero
rm -rf .claude/extensions/zotero
```
This removes all symlinks, unmerges index entries from `index.json`, and removes the EXTENSION.md section from CLAUDE.md.
