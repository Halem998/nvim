# Implementation Plan: Task #177

- **Task**: 177 - Remove all model preferences from opencode system
- **Status**: [NOT STARTED]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: specs/177_remove_model_preferences_from_opencode/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Remove all model preferences from the opencode agent system to fix ProviderModelNotFoundError when invoking planner-agent. The issue is that agent files specify `model: opus` in their frontmatter, but settings.json only has `"model": "sonnet"` with no `models` configuration section. This causes delegation to fail when the system cannot find a provider for "opus".

### Research Integration

Research identified 13 files requiring changes:
- 1 settings file (.opencode/settings.json)
- 2 core agent files (.opencode/agent/subagents/)
- 10 extension agent files across 5 extensions

All model specifications must be removed to ensure the system uses the default model without provider lookup failures.

## Goals & Non-Goals

**Goals**:
- Remove `"model": "sonnet"` from .opencode/settings.json
- Remove `model: opus` from all 12 agent files
- Verify no remaining model references exist in the codebase
- Ensure YAML frontmatter remains valid after removal

**Non-Goals**:
- Do not add new model configuration sections
- Do not modify files that already have no model specification
- Do not change agent functionality or behavior

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking agent functionality | High | Low | Test delegation after changes by running /research or /plan |
| Frontmatter parsing errors | Medium | Low | Verify YAML syntax remains valid (maintain --- delimiters) |
| Missing model causes fallback issues | Low | Low | System should use default model; monitor for errors |

## Implementation Phases

### Phase 1: Remove model from settings.json [COMPLETED]

**Goal**: Remove the global model preference from settings.json

**Tasks**:
- [ ] Read .opencode/settings.json
- [ ] Remove line 131: `"model": "sonnet"`,
- [ ] Ensure JSON remains valid (check trailing commas)

**Timing**: 5 minutes

**Files to modify**:
- `.opencode/settings.json` - Remove `"model": "sonnet"` line

**Verification**:
- [ ] File is valid JSON (no syntax errors)
- [ ] No `"model":` key remains in settings.json

---

### Phase 2: Remove model from core agents [COMPLETED]

**Goal**: Remove model preferences from core agent files

**Tasks**:
- [ ] Read .opencode/agent/subagents/planner-agent.md
- [ ] Remove line 4: `model: opus`
- [ ] Read .opencode/agent/subagents/general-research-agent.md
- [ ] Remove line 4: `model: opus`
- [ ] Verify frontmatter remains valid YAML

**Timing**: 10 minutes

**Files to modify**:
- `.opencode/agent/subagents/planner-agent.md` - Remove `model: opus` from frontmatter
- `.opencode/agent/subagents/general-research-agent.md` - Remove `model: opus` from frontmatter

**Verification**:
- [ ] Frontmatter maintains `---` delimiters
- [ ] `name:` and `description:` fields remain intact
- [ ] No `model:` key remains in either file

---

### Phase 3: Remove model from Neovim extension [COMPLETED]

**Goal**: Remove model preference from Neovim extension agent

**Tasks**:
- [ ] Read .opencode/extensions/nvim/agents/neovim-research-agent.md
- [ ] Remove line 4: `model: opus`
- [ ] Verify frontmatter remains valid YAML

**Timing**: 5 minutes

**Files to modify**:
- `.opencode/extensions/nvim/agents/neovim-research-agent.md` - Remove `model: opus` from frontmatter

**Verification**:
- [ ] Frontmatter maintains `---` delimiters
- [ ] No `model:` key remains in file

---

### Phase 4: Remove model from Lean extension [COMPLETED]

**Goal**: Remove model preferences from Lean extension agents

**Tasks**:
- [ ] Read .opencode/extensions/lean/agents/lean-implementation-agent.md
- [ ] Remove line 4: `model: opus`
- [ ] Read .opencode/extensions/lean/agents/lean-research-agent.md
- [ ] Remove line 4: `model: opus`
- [ ] Verify frontmatter remains valid YAML in both files

**Timing**: 10 minutes

**Files to modify**:
- `.opencode/extensions/lean/agents/lean-implementation-agent.md` - Remove `model: opus`
- `.opencode/extensions/lean/agents/lean-research-agent.md` - Remove `model: opus`

**Verification**:
- [ ] Frontmatter maintains `---` delimiters in both files
- [ ] No `model:` key remains in either file

---

### Phase 5: Remove model from LaTeX extension [COMPLETED]

**Goal**: Remove model preference from LaTeX extension agent

**Tasks**:
- [ ] Read .opencode/extensions/latex/agents/latex-research-agent.md
- [ ] Remove line 4: `model: opus`
- [ ] Verify frontmatter remains valid YAML

**Timing**: 5 minutes

**Files to modify**:
- `.opencode/extensions/latex/agents/latex-research-agent.md` - Remove `model: opus` from frontmatter

**Verification**:
- [ ] Frontmatter maintains `---` delimiters
- [ ] No `model:` key remains in file

---

### Phase 6: Remove model from Formal extension [COMPLETED]

**Goal**: Remove model preferences from Formal extension agents

**Tasks**:
- [ ] Read .opencode/extensions/formal/agents/physics-research-agent.md, remove `model: opus`
- [ ] Read .opencode/extensions/formal/agents/math-research-agent.md, remove `model: opus`
- [ ] Read .opencode/extensions/formal/agents/logic-research-agent.md, remove `model: opus`
- [ ] Read .opencode/extensions/formal/agents/formal-research-agent.md, remove `model: opus`
- [ ] Verify frontmatter remains valid YAML in all files

**Timing**: 15 minutes

**Files to modify**:
- `.opencode/extensions/formal/agents/physics-research-agent.md` - Remove `model: opus`
- `.opencode/extensions/formal/agents/math-research-agent.md` - Remove `model: opus`
- `.opencode/extensions/formal/agents/logic-research-agent.md` - Remove `model: opus`
- `.opencode/extensions/formal/agents/formal-research-agent.md` - Remove `model: opus`

**Verification**:
- [ ] Frontmatter maintains `---` delimiters in all files
- [ ] No `model:` key remains in any file

---

### Phase 7: Remove model from Epidemiology extension [COMPLETED]

**Goal**: Remove model preferences from Epidemiology extension agents

**Tasks**:
- [ ] Read .opencode/extensions/epidemiology/agents/epidemiology-implementation-agent.md
- [ ] Remove line 3: `model: opus`
- [ ] Read .opencode/extensions/epidemiology/agents/epidemiology-research-agent.md
- [ ] Remove line 3: `model: opus`
- [ ] Verify frontmatter remains valid YAML in both files

**Timing**: 10 minutes

**Files to modify**:
- `.opencode/extensions/epidemiology/agents/epidemiology-implementation-agent.md` - Remove `model: opus`
- `.opencode/extensions/epidemiology/agents/epidemiology-research-agent.md` - Remove `model: opus`

**Verification**:
- [ ] Frontmatter maintains `---` delimiters in both files
- [ ] No `model:` key remains in either file

---

### Phase 8: Verification [COMPLETED]

**Goal**: Verify no model references remain and all files are valid

**Tasks**:
- [ ] Search for `"model":` in .opencode/settings.json (should find nothing)
- [ ] Search for `model:` in all .opencode/agent/subagents/*.md frontmatter
- [ ] Search for `model:` in all .opencode/extensions/*/agents/*.md frontmatter
- [ ] Verify JSON syntax of settings.json
- [ ] Verify YAML frontmatter syntax in all modified agent files
- [ ] Test delegation by attempting to invoke planner-agent (run /plan on a test task)

**Timing**: 15 minutes

**Files to verify**:
- All 13 previously modified files
- Check no new files have model specifications

**Verification**:
- [ ] Zero occurrences of `"model":` in settings.json
- [ ] Zero occurrences of `model:` in agent file frontmatter
- [ ] All JSON files are valid
- [ ] All YAML frontmatters are valid
- [ ] Delegation works without ProviderModelNotFoundError

---

## Testing & Validation

- [ ] Verify settings.json is valid JSON
- [ ] Verify all agent files have valid YAML frontmatter
- [ ] Test planner-agent can be invoked (run /plan on task 72 or create test task)
- [ ] Confirm no ProviderModelNotFoundError occurs

## Artifacts & Outputs

- Modified .opencode/settings.json
- 12 modified agent files across core and extensions
- Git commit with all changes

## Rollback/Contingency

If delegation fails after changes:
1. Check if there's a default model configured at system level
2. If needed, restore files from git: `git checkout HEAD -- .opencode/settings.json .opencode/agent/subagents/*.md .opencode/extensions/*/agents/*.md`
3. Alternative approach: Add `models` configuration section to settings.json instead of removing all preferences

