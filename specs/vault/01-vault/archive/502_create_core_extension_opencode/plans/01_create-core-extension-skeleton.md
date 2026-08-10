# Implementation Plan: Task #502

- **Task**: 502 - Create core extension skeleton for .opencode/ mirroring .claude/extensions/core/ structure
- **Status**: [NOT STARTED]
- **Effort**: 4.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/502_create_core_extension_opencode/reports/01_core-extension-skeleton.md
- **Artifacts**: plans/01_create-core-extension-skeleton.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Create the core extension skeleton for OpenCode's `.opencode/extensions/core/` directory, mirroring the existing `.claude/extensions/core/` structure with adaptations for OpenCode's extension system. The core extension provides foundational agent system infrastructure including commands, agents, rules, skills, scripts, hooks, context, documentation, and templates.

### Research Integration

Integrated findings from research report 01_core-extension-skeleton.md:
- `.claude/extensions/core/` has 159 files across 13 categories
- OpenCode uses `opencode_md` merge target (not `claudemd`) and `EXTENSION.md` as source
- OpenCode loader config: `base_dir=".opencode"`, `merge_target_key="opencode_md"`, `agents_subdir="agent/subagents"`
- No existing `core/` extension in `.opencode/extensions/` (must be created)
- Manifest.json requires adaptation for OpenCode patterns

## Goals & Non-Goals

**Goals**:
- Create complete `.opencode/extensions/core/` directory structure matching `.claude/extensions/core/` layout
- Adapt manifest.json for OpenCode (use `opencode_md`, `EXTENSION.md`, proper `provides` structure)
- Create EXTENSION.md documentation for the core extension
- Copy all agent, command, skill, context, rule, hook, script, template, docs, and systemd files
- Create index-entries.json for context discovery integration
- Ensure extension can be loaded by OpenCode extension system

**Non-Goals**:
- Modifying the OpenCode extension loader code
- Creating new content (pure copy/port operation with adaptations)
- Setting up systemd services (files only, no activation)
- Modifying existing `.opencode/` root files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Large extension size (159+ files) slows loading | M | L | Extension loader handles efficiently; context lazy-loaded via index.json |
| File conflicts during copy to existing `.opencode/` | H | M | Use loader's `check_conflicts()`; clean up legacy files after loading |
| Incorrect manifest.json prevents extension loading | H | M | Follow OpenCode manifest pattern from existing extensions (e.g., `nvim`) |
| Merge target conflicts with `.opencode/AGENTS.md` | M | L | Use section markers (`extension_oc_core`); `generate_claudemd()` for clean regeneration |
| Broken references after moving files | M | L | Loader copies to correct locations; existing refs to `.opencode/agent/subagents/` still work |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |
| 2 | 4, 5 | 1, 2, 3 |
| 3 | 6, 7 | 4, 5 |
| 4 | 8 | 6, 7 |

Phases within the same wave can execute in parallel.

### Phase 1: Create manifest.json for OpenCode [COMPLETED]

**Goal**: Create the extension manifest adapted for OpenCode's extension system.

**Tasks**:
- [ ] Read `.claude/extensions/core/manifest.json` to understand structure
- [ ] Read existing OpenCode extension manifest (e.g., `.opencode/extensions/nvim/manifest.json`) for pattern reference
- [ ] Create `.opencode/extensions/core/manifest.json` with OpenCode adaptations:
  - Use `opencode_md` (not `claudemd`) for merge_targets
  - Use `EXTENSION.md` as source (not `merge-sources/claudemd.md`)
  - Use `extension_oc_core` as section_id
  - Populate `provides` object with all 159+ files across categories
  - Set `routing_exempt: true` (core is always loaded)
- [ ] Verify manifest.json is valid JSON

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.opencode/extensions/core/manifest.json` - Create new file

**Verification**:
- `jq empty .opencode/extensions/core/manifest.json` passes (valid JSON)
- Required fields present: `name`, `version`, `description`, `provides`, `merge_targets`
- `merge_targets.opencode_md.source` equals "EXTENSION.md"
- `merge_targets.opencode_md.section_id` equals "extension_oc_core"

---

### Phase 2: Create EXTENSION.md Documentation [COMPLETED]

**Goal**: Create extension documentation file for merging into `.opencode/AGENTS.md`.

**Tasks**:
- [ ] Create `.opencode/extensions/core/EXTENSION.md` using template from research:
  - Overview section explaining core extension purpose
  - What This Extension Provides table (agents, commands, rules, skills, scripts, hooks, context, docs, templates, systemd)
  - Key Capabilities section (task management, agent orchestration, state management, memory, extension infrastructure)
  - Usage Notes section
  - Dependencies section (none)
  - Related Files section
- [ ] Verify documentation is clear and complete

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.opencode/extensions/core/EXTENSION.md` - Create new file

**Verification**:
- File exists and is non-empty
- Contains all required sections (Overview, What This Extension Provides, Key Capabilities, Usage Notes, Dependencies, Related Files)
- Markdown renders correctly

---

### Phase 3: Create Directory Skeleton [COMPLETED]

**Goal**: Create all required directories for the core extension.

**Tasks**:
- [ ] Create `.opencode/extensions/core/` root directory
- [ ] Create `agents/` directory
- [ ] Create `commands/` directory
- [ ] Create `context/` directory with all subdirectories:
  - `context/architecture/`
  - `context/checkpoints/`
  - `context/formats/`
  - `context/guides/`
  - `context/meta/`
  - `context/orchestration/`
  - `context/patterns/`
  - `context/processes/`
  - `context/reference/`
  - `context/repo/`
  - `context/schemas/`
  - `context/standards/`
  - `context/templates/`
  - `context/troubleshooting/`
  - `context/workflows/`
- [ ] Create `docs/` directory with subdirectories:
  - `docs/architecture/`
  - `docs/examples/`
  - `docs/guides/`
  - `docs/reference/`
  - `docs/templates/`
- [ ] Create `hooks/` directory
- [ ] Create `scripts/` directory with `scripts/lint/` subdirectory
- [ ] Create `skills/` directory with all 17 skill subdirectories:
  - `skills/skill-fix-it/`, `skills/skill-git-workflow/`, `skills/skill-implementer/`, etc.
- [ ] Create `rules/` directory
- [ ] Create `templates/` directory
- [ ] Create `systemd/` directory
- [ ] Verify all directories created successfully

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- Create 40+ directories under `.opencode/extensions/core/`

**Verification**:
- All directories exist (use `find .opencode/extensions/core/ -type d | wc -l` to count)
- Directory structure matches `.claude/extensions/core/` layout

---

### Phase 4: Copy Agent, Command, and Skill Files [COMPLETED]

**Goal**: Copy agent definitions, command files, and skill definitions from `.claude/extensions/core/`.

**Tasks**:
- [ ] Copy agent files (8 agents + README):
  - `cp .claude/extensions/core/agents/*.md .opencode/extensions/core/agents/`
- [ ] Copy command files (15 commands):
  - `cp .claude/extensions/core/commands/*.md .opencode/extensions/core/commands/`
- [ ] Copy skill directories (17 skills):
  - `cp -r .claude/extensions/core/skills/skill-*/ .opencode/extensions/core/skills/`
- [ ] Verify all files copied:
  - 9 files in `agents/` (8 agents + README)
  - 15 files in `commands/`
  - 17 directories in `skills/` each with SKILL.md

**Timing**: 30 minutes

**Depends on**: Phase 3 (directory skeleton must exist)

**Files to modify**:
- Copy 41 files to `agents/`, `commands/`, `skills/`

**Verification**:
- `ls .opencode/extensions/core/agents/ | wc -l` returns 9
- `ls .opencode/extensions/core/commands/ | wc -l` returns 15
- `ls -d .opencode/extensions/core/skills/skill-*/ | wc -l` returns 17
- All SKILL.md files exist in each skill directory

---

### Phase 5: Copy Context Files [COMPLETED]

**Goal**: Copy all context files and directories from `.claude/extensions/core/context/`.

**Tasks**:
- [ ] Copy context subdirectories (16 directories + index.schema.json + routing.md + validation.md):
  - `cp -r .claude/extensions/core/context/* .opencode/extensions/core/context/`
- [ ] Verify context files copied:
  - All 16 subdirectories present
  - `index.schema.json` present
  - `routing.md` and `validation.md` present
- [ ] Count total context files to verify completeness:
  - Expected: 100+ files across all subdirectories

**Timing**: 30 minutes

**Depends on**: Phase 3 (directory skeleton must exist)

**Files to modify**:
- Copy 100+ files to `context/` subdirectories

**Verification**:
- `find .opencode/extensions/core/context/ -type f | wc -l` returns 100+
- All 16 expected subdirectories present
- `index.schema.json`, `routing.md`, `validation.md` exist in `context/`

---

### Phase 6: Copy Rules, Hooks, Scripts, Templates, Docs, Systemd [COMPLETED]

**Goal**: Copy remaining file categories (rules, hooks, scripts, templates, docs, systemd) from source.

**Tasks**:
- [ ] Copy rule files (7 rules):
  - `cp .claude/extensions/core/rules/*.md .opencode/extensions/core/rules/`
- [ ] Copy hook scripts (12 scripts):
  - `cp .claude/extensions/core/hooks/*.sh .opencode/extensions/core/hooks/`
- [ ] Copy script files (27+ scripts + lint/):
  - `cp -r .claude/extensions/core/scripts/* .opencode/extensions/core/scripts/`
- [ ] Copy template files (3 templates):
  - `cp .claude/extensions/core/templates/*.md .opencode/extensions/core/templates/`
  - `cp .claude/extensions/core/templates/settings.json .opencode/extensions/core/templates/`
- [ ] Copy docs directory (architecture/, examples/, guides/, reference/, templates/):
  - `cp -r .claude/extensions/core/docs/* .opencode/extensions/core/docs/`
- [ ] Copy systemd files (2 units):
  - `cp .claude/extensions/core/systemd/* .opencode/extensions/core/systemd/`
- [ ] Verify all files copied:
  - 7 files in `rules/`
  - 12 files in `hooks/`
  - 27+ files in `scripts/`
  - 3 files in `templates/`
  - 5+ directories in `docs/`
  - 2 files in `systemd/`

**Timing**: 30 minutes

**Depends on**: Phase 3 (directory skeleton must exist)

**Files to modify**:
- Copy 50+ files to `rules/`, `hooks/`, `scripts/`, `templates/`, `docs/`, `systemd/`

**Verification**:
- Count files in each directory matches expected counts
- All shell scripts in `hooks/` and `scripts/` have executable permissions
- README.md exists in `docs/`

---

### Phase 7: Create index-entries.json [COMPLETED]

**Goal**: Create context index entries for merging into `.opencode/context/index.json`.

**Tasks**:
- [ ] Examine `.claude/extensions/core/index-entries.json` to understand structure
- [ ] Examine `.opencode/context/index.json` to understand target format
- [ ] Create `.opencode/extensions/core/index-entries.json` with entries for:
  - All 18 context directories (architecture, checkpoints, formats, guides, meta, orchestration, patterns, processes, reference, repo, schemas, standards, templates, troubleshooting, workflows)
  - `routing.md` and `validation.md` entries
  - `index.schema.json` entry
  - Set appropriate `load_when` conditions (agents, commands, task_types, always)
  - Set correct `path` values relative to extension
- [ ] Verify index-entries.json is valid JSON
- [ ] Verify entries match manifest.json `provides.context` list

**Timing**: 1 hour

**Depends on**: Phase 5 (context files must be copied first)

**Files to modify**:
- `.opencode/extensions/core/index-entries.json` - Create new file

**Verification**:
- `jq empty .opencode/extensions/core/index-entries.json` passes (valid JSON)
- Entry count matches `provides.context` array length in manifest.json
- All paths reference valid files/directories under the extension
- `load_when` conditions are properly structured

---

### Phase 8: Verification and Testing [COMPLETED]

**Goal**: Verify the complete extension structure and test loading with OpenCode.

**Tasks**:
- [ ] Verify complete file count:
  - `find .opencode/extensions/core/ -type f | wc -l` should return 159+
- [ ] Verify manifest.json lists all files in `provides` object
- [ ] Verify EXTENSION.md exists and is valid markdown
- [ ] Verify index-entries.json exists and is valid JSON
- [ ] Test extension loading:
  - Open Neovim and run `<leader>ao` to open extension picker
  - Verify `core` extension appears in available extensions
  - Load `core` extension
  - Verify no errors during loading
- [ ] Verify `.opencode/AGENTS.md` contains core extension section after loading
- [ ] Verify `.opencode/context/index.json` contains merged entries from index-entries.json
- [ ] Check for any file conflicts or missing files
- [ ] Create summary of completed work

**Timing**: 1.5 hours

**Depends on**: Phase 6, 7 (all files must be copied and index created)

**Files to modify**:
- None (verification only)

**Verification**:
- Extension loads without errors in OpenCode
- `.opencode/AGENTS.md` contains `<!-- extension_oc_core -->` section
- `.opencode/context/index.json` contains entries from `index-entries.json`
- All 159+ files present in `.opencode/extensions/core/`
- `find .opencode/extensions/core/ -type f | wc -l` returns expected count

---

## Testing & Validation

- [ ] **File Count Validation**: Verify 159+ files exist in `.opencode/extensions/core/`
- [ ] **Manifest Validation**: `jq empty .opencode/extensions/core/manifest.json` passes
- [ ] **Index Validation**: `jq empty .opencode/extensions/core/index-entries.json` passes
- [ ] **Extension Loading**: Load extension via `<leader>ao` and verify no errors
- [ ] **AGENTS.md Merge**: Verify `.opencode/AGENTS.md` contains core extension section
- [ ] **Context Index Merge**: Verify `.opencode/context/index.json` has merged entries
- [ ] **Agent Subagents**: Verify agent files are copied to `.opencode/agent/subagents/` after loading
- [ ] **File Permissions**: Verify shell scripts have executable permissions

## Artifacts & Outputs

- `.opencode/extensions/core/manifest.json` - Extension manifest (adapted for OpenCode)
- `.opencode/extensions/core/EXTENSION.md` - Extension documentation
- `.opencode/extensions/core/index-entries.json` - Context index entries
- `.opencode/extensions/core/agents/` - 8 agent files + README
- `.opencode/extensions/core/commands/` - 15 command files
- `.opencode/extensions/core/skills/` - 17 skill directories
- `.opencode/extensions/core/context/` - 100+ context files across 16+ directories
- `.opencode/extensions/core/rules/` - 7 rule files
- `.opencode/extensions/core/hooks/` - 12 hook scripts
- `.opencode/extensions/core/scripts/` - 27+ utility scripts
- `.opencode/extensions/core/templates/` - 3 template files
- `.opencode/extensions/core/docs/` - Documentation files
- `.opencode/extensions/core/systemd/` - 2 systemd unit files

## Rollback/Contingency

If the extension causes issues or needs to be reverted:

1. **Unload Extension**: Use `<leader>ao` to unload the core extension
2. **Remove Extension Directory**: `rm -rf .opencode/extensions/core/`
3. **Restore AGENTS.md**: The merge system should remove the `extension_oc_core` section on unload
4. **Restore context/index.json**: The merge system should remove merged entries on unload
5. **Verify Clean State**: Ensure `.opencode/` returns to pre-implementation state

**Partial Implementation Recovery**:
- If interrupted during Phase 4-6 (file copying), simply re-run the copy commands
- If manifest.json is invalid, refer to `.opencode/extensions/nvim/manifest.json` for correct pattern
- If index-entries.json is incorrect, regenerate from `.claude/extensions/core/index-entries.json` template
