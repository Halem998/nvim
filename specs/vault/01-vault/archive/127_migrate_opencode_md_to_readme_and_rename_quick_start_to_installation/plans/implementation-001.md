# Implementation Plan: Task #127

**Task**: OC_127 - Migrate OPENCODE.md to README.md and rename QUICK-START.md to INSTALLATION.md
**Version**: 001
**Created**: 2026-03-03
**Language**: meta

## Overview

This plan consolidates the .opencode/ documentation by creating a comprehensive README.md from OPENCODE.md content, renaming QUICK-START.md to INSTALLATION.md with a focus on dependency installation, and adding cross-links to 20+ scattered README files. The approach is phased to ensure no documentation is lost and all cross-links are validated.

## Phases

### Phase 1: Create INSTALLATION.md from QUICK-START.md

**Status**: [COMPLETED]
**Actual effort**: 30 minutes

**Objectives**:
1. Rename QUICK-START.md to INSTALLATION.md
2. Refocus content on dependency installation only
3. Remove system status and architecture overview content (move to README.md)
4. Keep basic command examples as quick start

**Files to modify**:
- `.opencode/QUICK-START.md` → `.opencode/INSTALLATION.md` (rename)

**Steps**:
1. ✓ Rename QUICK-START.md to INSTALLATION.md
2. ✓ Rewrite introduction to focus on installation requirements
3. ✓ Create **Prerequisites** section:
   - Neovim (latest stable)
   - Git
   - Required system dependencies (jq, bash 4+, etc.)
4. ✓ Create **Installation** section:
   - Setup instructions
   - Directory structure setup
   - Verification commands
5. ✓ Keep **Quick Commands** section with first commands to try
6. ✓ Create **Troubleshooting** section:
   - Common setup issues
   - Verification steps
7. ✓ Remove or relocate to README.md:
   - "System Status: FULLY FUNCTIONAL"
   - "Key Improvement" section
   - "System Architecture" section
   - "Key Components" section
   - "Success Indicators" section

**Verification**:
- [x] INSTALLATION.md exists and QUICK-START.md is removed
- [x] File focuses on dependencies and installation
- [x] Basic command examples are preserved
- [x] No system status or architecture content

---

### Phase 2: Consolidate OPENCODE.md into README.md

**Status**: [COMPLETED]
**Actual effort**: 1.5 hours

**Objectives**:
1. Create comprehensive README.md from OPENCODE.md content
2. Add cross-links to all subdirectory README files
3. Add Extensions section with links to 9 extensions
4. Update directory structure diagram with cross-links

**Files to modify**:
- `.opencode/README.md` (overwrite existing minimal version)

**Steps**:
1. ✓ Start with OPENCODE.md content as base structure
2. ✓ Create new **System Overview** section:
   - Brief description: Task management and agent orchestration system
   - Purpose statement
3. ✓ Add **Quick Start** section:
   - Essential commands: `/task`, `/research`, `/plan`, `/implement`
   - Link to INSTALLATION.md for full setup
4. ✓ Keep **Core Features** section:
   - Task lifecycle management
   - Language-based routing table (neovim, lean, typst, latex, meta, general)
   - Checkpoint-based execution (GATE IN → DELEGATE → GATE OUT → COMMIT)
   - State synchronization between TODO.md and state.json
5. ✓ Keep **Command Reference** section:
   - Table with 20 commands
   - Link to `commands/README.md` for detailed syntax
6. ✓ Add **Extensions Overview** section:
   - List all 9 extensions with one-line descriptions:
     - lean - Lean 4 theorem proving with Lake build system
     - typst - Modern document typesetting
     - latex - Traditional document typesetting
     - formal - Formal verification (logic, math, physics)
     - python - Python development
     - nix - Nix package management
     - web - Web development
     - filetypes - File format conversion
     - z3 - Z3 theorem prover
   - Link to each extension's README.md
7. ✓ Update **Directory Structure** section:
   - Keep diagram
   - Add cross-links:
     - `commands/README.md` - Command definitions
     - `agent/subagents/README.md` - Agent documentation
     - `docs/README.md` - User guides and architecture
     - `context/README.md` - Context organization
     - `skills/` - Skill definitions
     - `extensions/<name>/` - Extension documentation
     - `rules/` - System rules and conventions
8. ✓ Keep **Task Management** section:
   - Status markers
   - Artifact paths convention
   - Language routing table
9. ✓ Keep **Rules References** section:
   - Brief mention of auto-applied rules
   - Links to `rules/` directory files
10. ✓ Keep **Context Imports** section:
    - Domain knowledge files
11. ✓ Keep **Error Handling** section
12. ✓ Keep **Git Commit Conventions** section
13. ✓ Keep **Skill-to-Agent Mapping** section (17 entries)
14. ✓ Keep **jq Command Safety** section

**Verification**:
- [x] README.md contains all OPENCODE.md content
- [x] Extensions section added with 9 extensions
- [x] Cross-links to subdirectory README files added
- [x] Directory structure includes navigation links

---

### Phase 3: Standardize Navigation Footers

**Status**: [COMPLETED]
**Actual effort**: 45 minutes

**Objectives**:
1. Add standardized navigation footer to all 20+ README files
2. Ensure consistent format: `[← Parent](../README.md) | [Subdirectory →](subdir/README.md)`
3. Update existing navigation if present

**Files modified**:
- `.opencode/commands/README.md`
- `.opencode/agent/subagents/README.md`
- `.opencode/docs/README.md`
- `.opencode/context/README.md`
- `.opencode/context/core/checkpoints/README.md`
- `.opencode/context/project/neovim/README.md`
- `.opencode/extensions/lean/context/project/lean4/README.md`
- `.opencode/extensions/typst/context/project/typst/README.md`
- `.opencode/extensions/latex/context/project/latex/README.md`
- `.opencode/extensions/formal/context/project/logic/README.md`
- `.opencode/extensions/formal/context/project/math/README.md`
- `.opencode/extensions/formal/context/project/physics/README.md`
- `.opencode/extensions/python/context/project/python/README.md`
- `.opencode/extensions/nix/context/project/nix/README.md`
- `.opencode/extensions/web/context/project/web/README.md`
- `.opencode/extensions/filetypes/context/project/filetypes/README.md`
- `.opencode/extensions/z3/context/project/z3/README.md`

**Steps**:
1. ✓ For each README.md file, add navigation footer at the end:
   ```markdown
   ---

   ## Navigation

   [← Parent Directory](../README.md)
   ```
2. ✓ If subdirectory has nested README files, add forward links:
   ```markdown
   ---

   ## Navigation

   [← Parent Directory](../README.md) | [Subdirectory →](subdir/README.md)
   ```
3. ✓ Check existing navigation and update to standardized format
4. ✓ Ensure relative paths are correct for each file location

**Verification**:
- [x] All 20+ README files have navigation footer
- [x] Navigation format is consistent across all files
- [x] Relative paths are correct for nested directories

---

### Phase 4: Remove OPENCODE.md and Update References

**Status**: [COMPLETED]
**Actual effort**: 30 minutes

**Objectives**:
1. Remove OPENCODE.md after README.md is validated
2. Search for any references to OPENCODE.md in codebase
3. Update references to point to README.md

**Files modified**:
- `.opencode/OPENCODE.md` (deleted)
- `.opencode/agent/orchestrator.md`
- `.opencode/agent/subagents/meta-builder-agent.md`
- `.opencode/agent/subagents/general-implementation-agent.md`
- `.opencode/agent/subagents/planner-agent.md`
- `.opencode/context/core/patterns/blocked-mcp-tools.md`
- `.opencode/context/project/repo/project-overview.md`
- `.opencode/docs/README.md`
- `.opencode/docs/guides/user-guide.md`
- `.opencode/docs/guides/user-installation.md`
- `.opencode/docs/guides/documentation-audit-checklist.md`
- `.opencode/docs/guides/documentation-maintenance.md`

**Steps**:
1. ✓ Search codebase for references to OPENCODE.md:
   ```bash
   grep -r "OPENCODE.md" /home/benjamin/.config/nvim/.opencode/ --include="*.md" --include="*.json" --include="*.lua"
   ```
2. ✓ Update any found references to point to README.md instead (19 total references updated)
3. ✓ Common places to check:
   - `.opencode/docs/README.md` (has link to OPENCODE.md)
   - Any agent files
   - Any command files
4. ✓ Delete OPENCODE.md:
   ```bash
   rm /home/benjamin/.config/nvim/.opencode/OPENCODE.md
   ```

**Verification**:
- [x] OPENCODE.md is removed
- [x] No broken references to OPENCODE.md exist
- [x] All previous references now point to README.md

---

### Phase 5: Validate All Cross-Links

**Status**: [COMPLETED]
**Actual effort**: 15 minutes

**Objectives**:
1. Validate all internal cross-links in documentation
2. Ensure no broken links exist
3. Verify navigation works between all README files

**Files checked**:
- All README.md files with cross-links

**Steps**:
1. ✓ Extract all markdown links from README.md files:
   ```bash
   grep -rE "\[.*\]\(.*\.md\)" /home/benjamin/.config/nvim/.opencode/ --include="*.md" | grep -v "http" > /tmp/links_to_check.txt
   ```
2. ✓ For each relative link, verify target file exists:
   - Check commands/README.md exists
   - Check agent/subagents/README.md exists
   - Check docs/README.md exists
   - Check all extension README files exist
   - Check all context README files exist
3. ✓ Test navigation from README.md to each subdirectory README
4. ✓ Test navigation from subdirectory README files back to parent README.md

**Verification**:
- [x] All cross-links in README.md resolve correctly
- [x] All navigation footers link to existing files
- [x] No broken internal links found

---

## Dependencies

- Phase 1 must complete before Phase 4 (INSTALLATION.md must exist before removing QUICK-START.md references)
- Phase 2 must complete before Phase 4 (README.md must exist before removing OPENCODE.md)
- Phase 3 can run in parallel with Phase 2 (navigation footers are independent)

## Risks & Mitigations

| Risk | Mitigation | Status |
|------|------------|--------|
| Users unable to find familiar OPENCODE.md | Add redirect notice in README.md mentioning consolidation; keep OPENCODE.md content structure intact | Mitigated - README.md contains all OPENCODE.md content |
| Broken cross-links after restructuring | Validate all links in Phase 5; use relative paths carefully | Mitigated - All links validated successfully |
| Missing content during migration | Keep OPENCODE.md until README.md is fully validated; use diff to compare | Mitigated - All content preserved in README.md |
| Inconsistent navigation footers | Use standardized format in Phase 3; verify all files updated | Mitigated - All 20+ files use consistent format |

## Success Criteria

- [x] INSTALLATION.md exists with dependency-focused content
- [x] QUICK-START.md is removed
- [x] README.md consolidates all OPENCODE.md content with cross-links
- [x] Extensions section with 9 extensions and links present
- [x] All 20+ README files have standardized navigation footer
- [x] OPENCODE.md is removed with no broken references
- [x] All internal cross-links validated and working

## Notes

**All phases completed successfully on 2026-03-03.**

**Total effort**: ~3 hours (matching original estimate)
**Files modified**: 32 total (2 created, 2 deleted, 28 updated)
**Commits**: 6 commits with session IDs for traceability

**Summary available at**: `specs/127_migrate_opencode_md_to_readme_and_rename_quick_start_to_installation/summaries/implementation-summary-20260303.md`
