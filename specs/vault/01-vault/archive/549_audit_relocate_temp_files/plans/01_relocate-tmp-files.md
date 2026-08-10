# Implementation Plan: Relocate /tmp/ References to specs/tmp/

- **Task**: 549 - audit_relocate_temp_files
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/549_audit_relocate_temp_files/reports/01_relocate-tmp-files.md
- **Artifacts**: plans/01_relocate-tmp-files.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace all `/tmp/` file path references across 14 OpenCode agent/skill/context files with `specs/tmp/` paths to keep temporary files within the project root and avoid `external_directory: "ask"` permission prompts. All replacements are direct text substitutions with no structural or logic changes. The `specs/tmp/` directory already exists and is actively used by core skills, confirming the migration path is viable.

### Research Integration

The research report at `specs/549_audit_relocate_temp_files/reports/01_relocate-tmp-files.md` identified 14 files with ~50 `/tmp/` references across 4 categories:
- **Category A** (extension SKILL.md files, 8 files): Active bash commands in postflight workflows using `/tmp/state.json` -- highest priority
- **Category B** (core context patterns, 2 files): Documentation example code with `/tmp/` paths
- **Category C** (project context processes, 3 files): Stale project copies whose core counterparts already use `specs/tmp/`
- **Category D** (documentation guides, 1 file): Outdated TTS integration guide referencing old `/tmp/` paths

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly align with this task. The task is a targeted cleanup of temp file paths across the OpenCode system.

## Goals & Non-Goals

**Goals**:
- Replace all `/tmp/state.json` references in extension SKILL.md files with `specs/tmp/state.json`
- Replace `/tmp/consult-meta-${session_id}.json` in skill-consult with `specs/tmp/consult-meta-${session_id}.json`
- Replace `/tmp/temp_data.csv` in spreadsheet-agent with `specs/tmp/temp_data.csv`
- Update core context pattern examples to use `specs/tmp/` paths
- Bring stale project context process files in line with their core counterparts
- Update TTS documentation to reflect current `specs/tmp/` paths

**Non-Goals**:
- Files already using `specs/tmp/` (~100+ files in codebase) -- these are correct
- Historical/reference documentation (`opencode-permission-configuration.md`, `permission-configuration.md`)
- Template files and prompt text that reference `/tmp/` for educational purposes
- Creating new documentation or context files about temp path conventions
- Modifying `specs/tmp/` directory structure or content

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Missing a `/tmp/` reference in an extension SKILL.md leaves runtime permission prompts | Medium | Low | Systematic grep verification before and after; research report provides exhaustive file list |
| Extension postflight scripts break if replacement is malformed | High | Low | All replacements are literal string swaps with no regex; verify each file's diff shows only path changes |
| Concurrent writes to `specs/tmp/state.json` from multiple extensions | Low | Very Low | Extensions execute postflights sequentially; `specs/tmp/state.json` pattern already established in core skills |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | -- |

Phases within the same wave can execute in parallel. Phase 1 is placed in Wave 1 to prioritize the runtime-critical extension files; Waves 2 phases are independent but placed after for review sequencing.

### Phase 1: Category A -- Extension SKILL.md Files [COMPLETED]

**Goal**: Replace all `/tmp/` paths in extension SKILL.md files with `specs/tmp/` equivalents, eliminating runtime permission prompts from extension postflight workflows.

**Tasks**:
- [x] **Task 1.1**: Replace `/tmp/state.json` with `specs/tmp/state.json` in web extension files (skill-web-implementation, skill-web-research) *(completed)*
- [x] **Task 1.2**: Replace `/tmp/state.json` with `specs/tmp/state.json` in lean extension files (skill-lean-implementation, skill-lean-research) *(completed)*
- [x] **Task 1.3**: Replace `/tmp/state.json` with `specs/tmp/state.json` in nix extension files (skill-nix-implementation) and nvim extension files (skill-neovim-implementation) *(completed)*
- [x] **Task 1.4**: Replace `/tmp/consult-meta-${session_id}.json` with `specs/tmp/consult-meta-${session_id}.json` in founder skill-consult *(completed)*
- [x] **Task 1.5**: Replace `/tmp/temp_data.csv` with `specs/tmp/temp_data.csv` in filetypes spreadsheet-agent *(completed)*
- [x] **Task 1.6**: Run grep verification to confirm zero remaining `/tmp/` references in extension files after changes *(completed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.opencode/extensions/web/skills/skill-web-implementation/SKILL.md` - 7 refs: `/tmp/state.json` in postflight jq commands
- `.opencode/extensions/web/skills/skill-web-research/SKILL.md` - 3 refs: `/tmp/state.json` in postflight jq commands
- `.opencode/extensions/lean/skills/skill-lean-implementation/SKILL.md` - 3 refs: `/tmp/state.json` in postflight jq commands
- `.opencode/extensions/lean/skills/skill-lean-research/SKILL.md` - 3 refs: `/tmp/state.json` in postflight jq commands
- `.opencode/extensions/nix/skills/skill-nix-implementation/SKILL.md` - 5 refs: `/tmp/state.json` in postflight jq commands
- `.opencode/extensions/nvim/skills/skill-neovim-implementation/SKILL.md` - 3 refs: `/tmp/state.json` in postflight jq commands
- `.opencode/extensions/founder/skills/skill-consult/SKILL.md` - 1 ref: `/tmp/consult-meta-${session_id}.json`
- `.opencode/extensions/filetypes/agents/spreadsheet-agent.md` - 1 ref: `/tmp/temp_data.csv`

**Verification**:
- `grep -rn '/tmp/' .opencode/extensions/ --include='*.md' | grep -v 'specs/tmp/'` returns no output
- Each modified file's diff shows only path changes, no structural modifications
- The `specs/tmp/state.json` path matches the pattern used in core skill files

### Phase 2: Category B -- Core Context Patterns [COMPLETED]

**Goal**: Update core context documentation files to use `specs/tmp/` paths in example code, bringing them in line with the already-correct project copies.

**Tasks**:
- [x] **Task 2.1**: Replace `/tmp/meta_base.json` and `/tmp/meta_with_artifacts.json` with `specs/tmp/meta_base.json` and `specs/tmp/meta_with_artifacts.json` in `file-metadata-exchange.md` *(completed)*
- [x] **Task 2.2**: Replace `/tmp/test-specs/state.json` with `specs/tmp/test-specs/state.json` in `jq-escaping-workarounds.md` *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `.opencode/context/core/patterns/file-metadata-exchange.md` - 4 refs: Pattern 2 example using `/tmp/meta_base.json`, `/tmp/meta_with_artifacts.json`
- `.opencode/context/core/patterns/jq-escaping-workarounds.md` - 5 refs: test script using `/tmp/test-specs/state.json`

**Verification**:
- `grep -rn '/tmp/' .opencode/context/core/patterns/ --include='*.md'` returns no output
- The project copy at `.opencode/context/patterns/file-metadata-exchange.md` already uses `specs/tmp/` (confirmed by research) and remains unchanged

### Phase 3: Category C -- Project Context Processes [COMPLETED]

**Goal**: Update stale project/processes/ workflow documentation files to use `specs/tmp/` paths, matching the already-correct core/processes/ counterparts.

**Tasks**:
- [x] **Task 3.1**: Replace `/tmp/task-${task_number}.md` with `specs/tmp/task-${task_number}.md` in `research-workflow.md` *(completed)*
- [x] **Task 3.2**: Replace `/tmp/task-${task_number}.md` with `specs/tmp/task-${task_number}.md` in `implementation-workflow.md` *(completed)*
- [x] **Task 3.3**: Replace `/tmp/task-${task_number}.md` with `specs/tmp/task-${task_number}.md` in `planning-workflow.md` *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `.opencode/context/project/processes/research-workflow.md` - 3 refs: selective task extraction example
- `.opencode/context/project/processes/implementation-workflow.md` - 2 refs: selective task extraction example
- `.opencode/context/project/processes/planning-workflow.md` - 2 refs: selective task extraction example

**Verification**:
- `grep -rn '/tmp/' .opencode/context/project/ --include='*.md'` returns no output
- Each file's project/ copy now matches the path patterns in its core/ counterpart

### Phase 4: Category D -- Documentation Guides [COMPLETED]

**Goal**: Update the TTS/STT integration guide to reflect current `specs/tmp/` paths, eliminating outdated `/tmp/` references.

**Tasks**:
- [x] **Task 4.1**: Replace old `/tmp/` TTS paths with current `specs/tmp/` equivalents in `tts-stt-integration.md` *(completed)*:
  - `/tmp/claude-tts-last-notify` → `specs/tmp/claude-tts-last-notify`
  - `/tmp/opencode-tts-notify.log` → `specs/tmp/opencode-tts-notify.log`
  - `/tmp/test.wav` → `specs/tmp/test.wav`
  - `/tmp/nvim-stt-recording.wav` → `specs/tmp/nvim-stt-recording.wav`

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `.opencode/docs/guides/tts-stt-integration.md` - 6 refs: TTS cooldown files, logs, and recordings

**Verification**:
- `grep -rn '/tmp/' .opencode/docs/guides/tts-stt-integration.md` returns no output
- Paths in documentation match the actual files found in `specs/tmp/` directory

## Testing & Validation

- [ ] Pre-change baseline: `grep -rn '/tmp/' .opencode/ --include='*.md' --include='*.sh' | grep -v 'specs/tmp/' | grep -v node_modules | grep -v 'docs/guides/opencode-permission' | grep -v 'docs/guides/permission-configuration' | grep -v 'templates/opencode.json'` captures full list of references to fix (should match research report)
- [ ] Post-change verification: same grep returns only the excluded reference/documentation files
- [ ] Spot-check 3-4 modified files with `git diff` to confirm only path changes
- [ ] Verify `specs/tmp/` directory still exists and is intact
- [ ] Verify core skill files (.opencode/extensions/core/) were not touched (they already use `specs/tmp/`)
- [ ] Verify excluded files (permission config guides, templates) were not touched

## Artifacts & Outputs

- `specs/549_audit_relocate_temp_files/plans/01_relocate-tmp-files.md` -- this plan
- Modified files (14 total):
  - 8 extension files (Phase 1)
  - 2 core context pattern files (Phase 2)
  - 3 project context process files (Phase 3)
  - 1 documentation guide (Phase 4)

## Rollback/Contingency

All changes are simple text replacements in markdown files. Rollback is a straightforward `git checkout --` on each of the 14 files. No database migrations, no configuration changes, no binary file modifications. If any file's postflight behavior breaks after replacement, revert that specific file and investigate the jq command context for hidden `/tmp/` uses not caught by grep.

The phased approach allows incremental verification: if Phase 1 changes cause issues after testing, revert Phase 1 without affecting Phases 2-4.
