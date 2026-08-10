# Implementation Plan: Task #170

- **Task**: 170 - Audit Agent Systems for Complete Wiring Correctness
- **Date**: 2026-03-10
- **Feature**: Fix broken .opencode extended system, index unindexed context files, resolve broken @-reference
- **Status**: [COMPLETED]
- **Estimated Hours**: 2-3 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)
- **Type**: meta
- **Lean Intent**: false

## Overview

The research audit found that the `.opencode/` extended system in `/home/benjamin/Projects/Logos/Vision/` is critically broken -- it contains extension-loaded files but zero core components (agents, skills, rules, commands, scripts, docs). The fix requires copying core content from `.opencode_core/` into `.opencode/` as the base layer, then verifying extension content coexists correctly. Additionally, 32 context files across 7 extensions lack index entries, and one @-reference points to a nonexistent file.

### Research Integration

- `.claude/` extended passes 35/35 validations; only needs minor index fixes
- `.opencode/` extended fails 13/18 checks due to missing ALL core content
- Extension loader (`shared/extensions/loader.lua`) only copies extension files -- it assumes core files already exist in the target directory
- Root cause: `.opencode/` was assembled with extensions but without first populating the core base layer
- 32 unindexed context files across typst (15), formal (8), lean (2), web (2), epidemiology (2), latex (1), python (1), z3 (1)

## Goals & Non-Goals

**Goals**:
- Restore `.opencode/` extended system to fully functional state with all core + extension content
- Add all 32 unindexed context files to their respective extension `index-entries.json` files
- Resolve the broken `project/repo/project-overview.md` @-reference
- Achieve 35/35 pass rate on validate-wiring.sh for both `.claude/` and `.opencode/` extended systems

**Non-Goals**:
- Modifying `.claude_core/` or `.opencode_core/` baseline systems (these are clean)
- Standardizing routing table column headers (cosmetic, deferred)
- Adding `code-reviewer-agent` to `.claude_core/` (cross-system asymmetry is by design)
- Changing the extension loader architecture

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Core copy overwrites extension files | H | L | Copy core first, verify extension files still present after |
| Extension index-entries.json format errors | M | L | Validate JSON after each edit, run validate-wiring.sh |
| .opencode agent path mismatch (agent/subagents vs agents) | H | M | Verify config.lua agents_subdir="agent/subagents" mapping is preserved |
| Context file paths in index-entries don't match actual paths | M | M | Cross-reference disk files with index entries after adding |

## Implementation Phases

### Phase 1: Repair .opencode Extended System - Core Layer [COMPLETED]

**Goal**: Copy all core content from `.opencode_core/` into `.opencode/` without disturbing existing extension content.

**Tasks**:
- [ ] Back up current `.opencode/OPENCODE.md` (it has extension sections injected)
- [ ] Copy core directories from `.opencode_core/` to `.opencode/`: `agent/` (core agents into `agent/subagents/`), `skills/`, `rules/`, `commands/`, `scripts/`, `docs/`, `hooks/`, `systemd/`, `templates/`
- [ ] Copy `README.md` from `.opencode_core/` to `.opencode/`
- [ ] Verify core agents are now present alongside extension agents in `agent/subagents/`
- [ ] Verify core skills are now present alongside extension skills in `skills/`
- [ ] Verify core rules are now present alongside extension rules in `rules/`
- [ ] Verify commands directory is populated (was empty: 0 of 20)
- [ ] Verify scripts directory is populated (was empty: 0 of 16)
- [ ] Merge core context index entries (10 entries) into `.opencode/context/index.json` alongside existing 145 extension entries

**Timing**: 1 hour

**Files to modify**:
- `.opencode/agent/subagents/` - Add 5 core agents (general-implementation-agent, general-research-agent, meta-builder-agent, planner-agent, code-reviewer-agent)
- `.opencode/skills/` - Add 12 core skills
- `.opencode/rules/` - Add 5 core rules
- `.opencode/commands/` - Add 20 core commands (currently empty)
- `.opencode/scripts/` - Add 16 core scripts (currently empty)
- `.opencode/docs/` - Add entire docs directory
- `.opencode/hooks/` - Add hooks directory
- `.opencode/systemd/` - Add systemd directory
- `.opencode/templates/` - Add templates directory
- `.opencode/context/index.json` - Merge 10 core entries with 145 extension entries

**Verification**:
- `ls .opencode/agent/subagents/ | wc -l` shows 32+ files (5 core + 27 extension)
- `ls .opencode/skills/ | wc -l` shows 40+ items (12 core + 28 extension)
- `ls .opencode/rules/ | wc -l` shows 10+ files (5 core + 5 extension)
- `ls .opencode/commands/ | wc -l` shows 20+ files
- `ls .opencode/scripts/ | wc -l` shows 16+ files
- `jq '.entries | length' .opencode/context/index.json` shows 155 (10 core + 145 extension)

---

### Phase 2: Repair .opencode OPENCODE.md Core Content [COMPLETED]

**Goal**: Ensure OPENCODE.md has core content sections in addition to the 11 extension sections already injected.

**Tasks**:
- [ ] Compare `.opencode/OPENCODE.md` against `.opencode_core/README.md` to identify missing core sections
- [ ] Verify the OPENCODE.md has the base routing table, task management, state sync, and other core sections
- [ ] If core sections are missing, merge them from `.opencode_core/README.md` into OPENCODE.md (above extension sections)
- [ ] Verify all 11 extension sections are still present after merge
- [ ] Verify `settings.json` or `settings.local.json` is correct

**Timing**: 30 minutes

**Files to modify**:
- `.opencode/OPENCODE.md` - Merge core content if missing

**Verification**:
- OPENCODE.md contains core routing table with language-based routing
- OPENCODE.md contains all 11 `extension_oc_` sections
- OPENCODE.md references correct skill-to-agent mapping

---

### Phase 3: Add Unindexed Context Files to Extension Indices [COMPLETED]

**Goal**: Add 32 unindexed context files to their respective extension `index-entries.json` files in the nvim config extension sources.

**Tasks**:
- [ ] Add 15 typst context files to `.claude/extensions/typst/index-entries.json` and `.opencode/extensions/typst/index-entries.json`
- [ ] Add 8 formal context files to `.claude/extensions/formal/index-entries.json` and `.opencode/extensions/formal/index-entries.json`
- [ ] Add 2 lean context files to `.claude/extensions/lean/index-entries.json` and `.opencode/extensions/lean/index-entries.json`
- [ ] Add 2 web context files to `.claude/extensions/web/index-entries.json` and `.opencode/extensions/web/index-entries.json`
- [ ] Add 2 epidemiology context files to `.claude/extensions/epidemiology/index-entries.json` and `.opencode/extensions/epidemiology/index-entries.json`
- [ ] Add 1 latex context file to `.claude/extensions/latex/index-entries.json` and `.opencode/extensions/latex/index-entries.json`
- [ ] Add 1 python context file to `.claude/extensions/python/index-entries.json` and `.opencode/extensions/python/index-entries.json`
- [ ] Add 1 z3 context file to `.claude/extensions/z3/index-entries.json` and `.opencode/extensions/z3/index-entries.json`
- [ ] Validate all modified JSON files parse correctly

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/typst/index-entries.json` - Add 15 entries
- `.opencode/extensions/typst/index-entries.json` - Add 15 entries (mirror)
- `.claude/extensions/formal/index-entries.json` - Add 8 entries
- `.opencode/extensions/formal/index-entries.json` - Add 8 entries (mirror)
- `.claude/extensions/lean/index-entries.json` - Add 2 entries
- `.opencode/extensions/lean/index-entries.json` - Add 2 entries (mirror)
- `.claude/extensions/web/index-entries.json` - Add 2 entries
- `.opencode/extensions/web/index-entries.json` - Add 2 entries (mirror)
- `.claude/extensions/epidemiology/index-entries.json` - Add 2 entries
- `.opencode/extensions/epidemiology/index-entries.json` - Add 2 entries (mirror)
- `.claude/extensions/latex/index-entries.json` - Add 1 entry
- `.opencode/extensions/latex/index-entries.json` - Add 1 entry (mirror)
- `.claude/extensions/python/index-entries.json` - Add 1 entry
- `.opencode/extensions/python/index-entries.json` - Add 1 entry (mirror)
- `.claude/extensions/z3/index-entries.json` - Add 1 entry
- `.opencode/extensions/z3/index-entries.json` - Add 1 entry (mirror)

**Verification**:
- All 16 JSON files parse without error: `jq . < file.json > /dev/null`
- Entry counts match expectations per extension
- Each new entry has required fields: `path`, `description`, `load_when`

---

### Phase 4: Fix Broken @-Reference (project-overview.md) [COMPLETED]

**Goal**: Resolve the broken reference to `project/repo/project-overview.md` that exists in CLAUDE.md / OPENCODE.md context imports.

**Tasks**:
- [ ] Determine if `project-overview.md` should be created or the reference should be removed/updated
- [ ] Check what content the reference is expected to provide (Vision project overview)
- [ ] Either create `context/project/repo/project-overview.md` in both `.claude/` and `.opencode/` extended systems, OR update the @-reference in CLAUDE.md/OPENCODE.md to point to an existing file
- [ ] If creating the file, also add it to context `index.json` in both systems

**Timing**: 15 minutes

**Files to modify**:
- Either: `.claude/context/project/repo/project-overview.md` and `.opencode/context/project/repo/project-overview.md` (new files)
- Or: CLAUDE.md and OPENCODE.md @-reference lines (update references)

**Verification**:
- The @-reference in CLAUDE.md/OPENCODE.md points to an existing file
- If file was created, it contains meaningful project overview content

---

### Phase 5: Reload Extensions and Final Validation [COMPLETED]

**Goal**: Re-deploy extensions to `.opencode/` extended system (now that core is present) and run full validation on all 4 systems.

**Tasks**:
- [ ] Reload all 11 extensions into `.opencode/` via the Neovim extension loader (or manually re-copy extension content that may have been affected by Phase 1)
- [ ] Reload extensions into `.claude/` to pick up new index entries from Phase 3
- [ ] Run `validate-wiring.sh` against `.claude/` extended system -- expect 35/35 pass
- [ ] Run `validate-wiring.sh` against `.opencode/` extended system -- expect 35/35 pass (was 18/35)
- [ ] Run `validate-wiring.sh` against `.claude_core/` -- confirm still clean
- [ ] Run `validate-wiring.sh` against `.opencode_core/` -- confirm still clean
- [ ] Verify no regressions in extension section injection
- [ ] Verify routing chains are complete for all languages in both extended systems

**Timing**: 30 minutes

**Files to modify**:
- `.claude/context/index.json` - Updated with new index entries from Phase 3
- `.opencode/context/index.json` - Updated with new index entries from Phase 3

**Verification**:
- `.claude/` extended: 35/35 PASS, 0 WARN, 0 FAIL
- `.opencode/` extended: 35/35 PASS, 0 WARN, 0 FAIL (was 18 PASS, 4 WARN, 13 FAIL)
- `.claude_core/`: No extension contamination
- `.opencode_core/`: No extension contamination
- All extension context files discoverable via `jq` queries on `index.json`

---

## Testing & Validation

- [ ] `validate-wiring.sh` passes 35/35 for `.claude/` extended
- [ ] `validate-wiring.sh` passes 35/35 for `.opencode/` extended
- [ ] Both core systems remain clean (no extension contamination)
- [ ] All 32 previously-unindexed context files appear in index queries
- [ ] No broken @-references remain in CLAUDE.md or OPENCODE.md
- [ ] Extension loader can still load/unload extensions after core repair

## Artifacts & Outputs

- Repaired `.opencode/` extended system with all core + extension content
- Updated `index-entries.json` for 8 extensions (both claude and opencode variants)
- Resolved `project-overview.md` reference
- Clean validation reports for all 4 systems

## Rollback/Contingency

Phase 1 is the highest-risk phase. If core file copying causes issues:
1. The `.opencode/OPENCODE.md.backup` file preserves the pre-repair state
2. Extension content can be restored by re-running the extension loader
3. Core systems (`.claude_core/`, `.opencode_core/`) are never modified and serve as ground truth
4. If `.opencode/` becomes unsalvageable, delete it entirely and rebuild from `.opencode_core/` + extension reload
