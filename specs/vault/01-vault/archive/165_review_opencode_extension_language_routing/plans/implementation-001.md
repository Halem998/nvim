# Implementation Plan: Task #165

- **Task**: 165 - review_opencode_extension_language_routing
- **Status**: [COMPLETED]
- **Effort**: 3-5 hours
- **Dependencies**: None
- **Research Inputs**: specs/165_review_opencode_extension_language_routing/reports/research-001.md
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md
- **Type**: meta
- **Lean Intent**: false
- **Date**: 2026-03-10
- **Feature**: Fix extension language routing so tasks route to correct specialized agents
- **Estimated Hours**: 3-5 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)

## Overview

The .opencode/ agent system has 10 extensions providing specialized agents and context, but commands hardcode delegation to generic skills regardless of task language. This plan expands the routing tables in `/research` and `/implement` commands to dispatch to extension-specific skills, updates orchestration-core.md to document all language routes, merges missing extension index entries into the main context/index.json, adds routing validation for all extension languages, and creates a merge-extensions.sh utility script for future extension registration.

### Research Integration

Research identified 8 gaps (findings 1-8) with the Hybrid approach (Option C) recommended. Key findings integrated:
- Commands hardcode `skill-researcher` / `skill-implementer` (finding 1)
- Orchestration routing table only covers lean/neovim/default (finding 2)
- Routing validation only checks lean and neovim (finding 3)
- Extension index-entries.json not merged for z3, nix, python (finding 4)
- Extension skills exist but are never called (finding 5)
- No extension registration mechanism (finding 6)

## Goals & Non-Goals

**Goals**:
- Route all extension languages to their specialized skills and agents
- Merge all extension index-entries.json into main context/index.json
- Validate routing for all extension languages
- Create merge-extensions.sh script for reproducible index merging
- Document the extension registration process

**Non-Goals**:
- Dynamic runtime extension discovery (static routing tables are sufficient)
- Creating new extension agents or skills (they already exist)
- Changing the skill-to-agent delegation within extension skills (already correct)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing lean/neovim routing | H | L | Preserve existing entries, only add new ones |
| Command files becoming too large with routing tables | M | L | Use compact table format, keep routing lookup pattern simple |
| Missing agent files for some extensions | M | L | Verify all referenced agent/skill files exist before updating |
| Formal extension maps multiple languages (formal, logic, math, physics) | M | M | Handle as multi-language mapping in routing tables |

## Implementation Phases

### Phase 1: Expand Command Routing Tables [COMPLETED]

**Goal**: Update `/research` and `/implement` commands to route tasks to the correct extension skills based on language.

**Tasks**:
- [ ] Update `.opencode/commands/research.md` Step 6 to use language-based skill selection instead of hardcoded `skill-researcher`
- [ ] Add complete language-to-skill routing table in research.md covering all 10+ languages
- [ ] Update `.opencode/commands/research.md` Step 7a-verify agent_type verification table to include all extension agents
- [ ] Update `.opencode/commands/implement.md` Step 5 to use language-based skill selection instead of hardcoded `skill-implementer`
- [ ] Add complete language-to-skill routing table in implement.md covering all 10+ languages
- [ ] Update `.opencode/commands/implement.md` Step 7a-verify agent_type verification table to include all extension agents

**Timing**: 1.5 hours

**Files to modify**:
- `.opencode/commands/research.md` - Replace hardcoded skill-researcher with language-routed skill dispatch; expand agent verification table
- `.opencode/commands/implement.md` - Replace hardcoded skill-implementer with language-routed skill dispatch; expand agent verification table

**Specific Changes**:

For `research.md` Step 6, replace:
```
Name: skill-researcher
```
With a conditional routing table:
```
| Language | Skill |
|----------|-------|
| neovim | skill-neovim-research |
| lean4 | skill-lean-research |
| z3 | skill-z3-research |
| nix | skill-nix-research |
| python | skill-python-research |
| latex | skill-latex-research |
| typst | skill-typst-research |
| web | skill-web-research |
| epidemiology | skill-epidemiology-research |
| formal, logic, math, physics | skill-formal-research |
| general, meta, markdown | skill-researcher |
```

For `research.md` Step 7a-verify agent verification, expand:
```
| Language | Expected agent_type |
|----------|---------------------|
| neovim | neovim-research-agent |
| lean4 | lean-research-agent |
| z3 | z3-research-agent |
| nix | nix-research-agent |
| python | python-research-agent |
| latex | latex-research-agent |
| typst | typst-research-agent |
| web | web-research-agent |
| epidemiology | epidemiology-research-agent |
| formal | formal-research-agent |
| logic | logic-research-agent |
| math | math-research-agent |
| physics | physics-research-agent |
| general, meta, markdown | general-research-agent |
```

Apply equivalent changes to `implement.md` for implementation skills and agents.

**Verification**:
- Read both command files and confirm routing tables are complete
- Verify all referenced skill names match actual skill directory names in `.opencode/extensions/*/skills/`
- Verify all referenced agent names match actual agent file names in `.opencode/extensions/*/agents/`

---

### Phase 2: Update Orchestration Core Routing [COMPLETED]

**Goal**: Expand the orchestration-core.md routing table and validation to cover all extension languages.

**Tasks**:
- [ ] Expand the Command -> Agent Mapping table (lines 182-189) to include all extension languages
- [ ] Expand routing validation (lines 213-224) to validate all extension language-agent pairs
- [ ] Verify the routing table is consistent with command routing tables from Phase 1

**Timing**: 0.5 hours

**Files to modify**:
- `.opencode/context/core/orchestration/orchestration-core.md` - Expand routing table and validation section

**Specific Changes**:

Expand the routing table at line 182-189:
```
| Command | Language-Based | Agent(s) |
|---------|---------------|----------|
| /research | Yes | lean4: lean-research-agent, neovim: neovim-research-agent, z3: z3-research-agent, nix: nix-research-agent, python: python-research-agent, latex: latex-research-agent, typst: typst-research-agent, web: web-research-agent, epidemiology: epidemiology-research-agent, formal/logic/math/physics: formal-research-agent, default: general-research-agent |
| /implement | Yes | lean4: lean-implementation-agent, neovim: neovim-implementation-agent, z3: z3-implementation-agent, nix: nix-implementation-agent, python: python-implementation-agent, latex: latex-implementation-agent, typst: typst-implementation-agent, web: web-implementation-agent, epidemiology: epidemiology-implementation-agent, default: general-implementation-agent |
| /plan | No | planner-agent |
| /revise | No | planner-agent |
| /review | No | reviewer-agent |
| /meta | No | meta-builder-agent |
```

Expand routing validation to add checks for each extension language:
```bash
# Extension language routing validation
for lang_agent in "z3:z3-" "nix:nix-" "python:python-" "latex:latex-" "typst:typst-" "web:web-" "epidemiology:epidemiology-"; do
  lang="${lang_agent%%:*}"
  prefix="${lang_agent##*:}"
  if [ "$language" == "$lang" ] && [[ ! "$agent" =~ ^${prefix} ]]; then
    echo "Error: ${lang} task must route to ${prefix}* agent"
    exit 1
  fi
done
```

**Verification**:
- Read orchestration-core.md and confirm all languages from the CLAUDE.md routing table are present
- Confirm validation covers all extension languages

---

### Phase 3: Merge Extension Index Entries [COMPLETED]

**Goal**: Merge missing extension index-entries.json into the main context/index.json and fix incorrect agent mappings.

**Tasks**:
- [ ] Read each extension's index-entries.json to identify entries missing from main index
- [ ] Merge z3 extension entries (4 entries for z3-research-agent, z3-implementation-agent)
- [ ] Merge nix extension entries into main index
- [ ] Merge python extension entries into main index
- [ ] Fix web context entry: change agent from `general-research-agent` to `web-research-agent` and `web-implementation-agent`
- [ ] Verify all extension entries reference correct agent names
- [ ] Ensure no duplicate entries after merge

**Timing**: 0.75 hours

**Files to modify**:
- `.opencode/context/index.json` - Add missing extension entries, fix agent mappings

**Verification**:
- Validate index.json is valid JSON after edits
- Count entries and confirm expected total (22 existing + new entries)
- Verify every extension language has at least one entry with correct agent references
- Check that web entry references web-specific agents, not general-research-agent

---

### Phase 4: Create merge-extensions.sh Script [COMPLETED]

**Goal**: Create a utility script that reads all extension manifests and merges their index-entries.json into the main context/index.json, enabling reproducible registration.

**Tasks**:
- [ ] Create `.opencode/scripts/merge-extensions.sh` script
- [ ] Script reads all `.opencode/extensions/*/manifest.json` files
- [ ] For each extension with `merge_targets.index`, merge source entries into target
- [ ] Handle deduplication (skip entries with matching path)
- [ ] Add --dry-run flag to preview changes
- [ ] Add --verify flag to check current index completeness without modifying
- [ ] Make script idempotent (safe to run multiple times)

**Timing**: 0.75 hours

**Files to modify**:
- `.opencode/scripts/merge-extensions.sh` - New file: extension index merge utility

**Script Outline**:
```bash
#!/usr/bin/env bash
# merge-extensions.sh - Merge extension index entries into main context/index.json
# Usage: merge-extensions.sh [--dry-run] [--verify]

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
EXTENSIONS_DIR="$PROJECT_DIR/.opencode/extensions"
INDEX_FILE="$PROJECT_DIR/.opencode/context/index.json"

# For each extension with manifest.json containing merge_targets.index:
#   1. Read extension's index-entries.json
#   2. Check each entry against existing index
#   3. Add missing entries to index
#   4. Report what was added/skipped
```

**Verification**:
- Run script with --dry-run and confirm it identifies correct missing entries
- Run script with --verify and confirm it reports current index completeness
- Run script to merge, then run again to verify idempotency

---

### Phase 5: Document Extension Registration Process [COMPLETED]

**Goal**: Document the steps needed when adding a new extension, so future extensions are correctly registered.

**Tasks**:
- [ ] Add "Extension Registration" section to `.opencode/context/core/orchestration/orchestration-core.md` describing the process
- [ ] Document: 1) Create extension directory with manifest, skills, agents, context 2) Run merge-extensions.sh 3) Add language to command routing tables 4) Add routing validation entry
- [ ] Update the .opencode/ README or OPENCODE.md if one exists to reference extension registration

**Timing**: 0.5 hours

**Files to modify**:
- `.opencode/context/core/orchestration/orchestration-core.md` - Add Extension Registration section
- `.opencode/README.md` or equivalent - Add reference to extension registration process

**Verification**:
- Read the documentation and confirm a new extension developer could follow the steps
- Verify all referenced scripts and files exist

---

## Testing & Validation

- [ ] All language types from .claude/CLAUDE.md routing table have corresponding entries in command routing tables
- [ ] Orchestration-core.md routing table matches command routing tables
- [ ] Routing validation covers all extension languages
- [ ] context/index.json contains entries for all extensions with correct agent references
- [ ] merge-extensions.sh runs successfully with --verify and reports 100% coverage
- [ ] Existing lean and neovim routing is preserved (no regression)
- [ ] All referenced skill files exist at expected paths
- [ ] All referenced agent files exist at expected paths

## Artifacts & Outputs

- Modified `.opencode/commands/research.md` with complete language routing
- Modified `.opencode/commands/implement.md` with complete language routing
- Modified `.opencode/context/core/orchestration/orchestration-core.md` with expanded routing and validation
- Modified `.opencode/context/index.json` with all extension entries merged
- New `.opencode/scripts/merge-extensions.sh` utility script
- Updated documentation for extension registration process

## Rollback/Contingency

All changes are to markdown files and one JSON file within `.opencode/`. If implementation fails:
1. `git checkout -- .opencode/commands/research.md .opencode/commands/implement.md` to restore command routing
2. `git checkout -- .opencode/context/core/orchestration/orchestration-core.md` to restore orchestration core
3. `git checkout -- .opencode/context/index.json` to restore original index
4. Remove `.opencode/scripts/merge-extensions.sh` if script causes issues

No external dependencies or system changes are involved. All changes are confined to `.opencode/` directory.
