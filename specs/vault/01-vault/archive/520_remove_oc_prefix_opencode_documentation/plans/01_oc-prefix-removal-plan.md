# Implementation Plan: Remove OC_ Prefix from OpenCode Documentation and Standards

- **Task**: 520 - Remove OC_ prefix from OpenCode documentation and standards
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/520_remove_oc_prefix_opencode_documentation/reports/01_oc-prefix-audit.md
- **Artifacts**: plans/01_oc-prefix-removal-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Remove all `OC_` prefix references from `.opencode/` documentation and standards. The actual task directories already use plain numbers (e.g., `specs/520_slug/`), but documentation still instructs agents to use `OC_` prefixes, creating confusion and potential path mismatches. This plan covers 18 distinct file groups across core files, skills, patterns, rules, docs, and extension mirrors.

### Research Integration

The research report identified 241 `OC_` references across `.opencode/` markdown files. Key findings:
- No legacy `OC_503_*` directories exist in the repository
- Extension mirrors in `.opencode/extensions/core/` duplicate core content and must be updated in parallel
- Bash scripts contain `OC_` stripping logic that should be removed
- Regex patterns match both `OC_N` and `N` formats and should be simplified

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Remove all `OC_` prefix references from documentation, examples, and bash scripts
- Update path conventions to use plain numbers consistently
- Update regex patterns to match only plain numbers
- Update extension mirrors in parallel with core files
- Verify no broken references remain after changes

**Non-Goals**:
- Rename existing task directories (they already use plain numbers)
- Modify `specs/TODO.md` task headers (handled separately if needed)
- Change git history or past commits

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Bash scripts break if OC_ directories still exist | High | Low | Verify no OC_ directories exist before deployment |
| Regex changes break task header parsing | Medium | Low | Test task header regex against actual TODO.md format |
| Extension files get out of sync | Medium | Medium | Update extension mirrors in same commit wave |
| Accidental replacement of legitimate "OC_" strings | Low | Low | Review all changes with grep before committing |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Pre-Flight Verification [COMPLETED]

**Goal**: Confirm the environment is safe for mass replacement and establish baseline.

**Tasks**:
- [ ] Run `find . -maxdepth 1 -name 'OC_*' -type d` and `find specs/ -name 'OC_*' -type d` to confirm no legacy directories exist
- [ ] Run `grep -r "OC_" .opencode/ --include="*.md" | wc -l` to establish baseline count
- [ ] Verify all target files are tracked in git: `git ls-files .opencode/ | grep -E '\.md$'`
- [ ] Create a backup branch: `git checkout -b task-520-oc-prefix-removal`

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- None (verification only)

**Verification**:
- No `OC_*` directories found
- Baseline count recorded (should be ~241)
- All targets tracked in git
- Backup branch created

---

### Phase 2: Update Core Files [COMPLETED]

**Goal**: Apply all `OC_` prefix removals to core `.opencode/` files.

**Tasks**:

**2.1 Standards and State Management**
- [ ] `.opencode/context/core/standards/task-management.md` (lines 23, 28, 30-33, 39, 40)
  - Replace `OC_17` with `17`, `OC_017_task_slug` with `017_task_slug`
  - Replace `OC_{Task ID}` with `{Task ID}`
  - Replace `task OC_17:` with `task 17:`
- [ ] `.opencode/context/core/orchestration/state-management.md` (lines 60, 64, 124-126, 135, 146-154, 270, 272-273, 281)
  - Remove `OC_` prefix from directory examples
  - Remove `sed 's/^OC_//'` stripping logic
  - Update `task_display` and `task_dir` variables
  - Update `grep` pattern for TODO.md headers

**2.2 Patterns and Formats**
- [ ] `.opencode/context/core/patterns/metadata-file-return.md` (lines 99, 102, 123, 138)
  - Replace `specs/OC_${padded_num}` with `specs/${padded_num}`
- [ ] `.opencode/context/core/patterns/postflight-control.md` (line 158)
  - Replace `specs/OC_${padded_num}` with `specs/${padded_num}`
- [ ] `.opencode/context/core/patterns/file-metadata-exchange.md` (lines 28, 39, 42, 90, 111, 129, 148, 172, 180, 199, 204, 244)
  - Replace all `specs/OC_${padded_num}` with `specs/${padded_num}`
- [ ] `.opencode/context/core/formats/return-metadata-file.md` (lines 143, 170, 183)
  - Replace all `specs/OC_${padded_num}` with `specs/${padded_num}`

**2.3 Reference and Rules**
- [ ] `.opencode/context/core/reference/state-management-schema.md` (line 322)
  - Replace Claude Code/OpenCode distinction with unified plain number statement
- [ ] `.opencode/rules/artifact-formats.md` (lines 23, 24)
  - Remove Claude Code line, update OpenCode line to "All tasks"

**2.4 Skills**
- [ ] `.opencode/skills/skill-todo/SKILL.md` (lines 47, 50, 68, 71, 84, 95, 98, 246-247, 291)
  - Remove `OC_[0-9]*_*/` from directory loops
  - Remove `sed 's/^OC_//'` from project_num extraction
  - Update regex pattern: `"###%s+(OC_)?(%d+)%.%s+"` to `"###%s+(%d+)%.%s+"`
  - Update `source_dir` path
- [ ] `.opencode/skills/skill-memory/SKILL.md` (lines 550, 553, 557, 901)
  - Replace `specs/OC_${padded_num}` with `specs/${padded_num}`
  - Replace `specs/OC_${task_num}` with `specs/${task_num}`

**2.5 Guides and Commands**
- [ ] `.opencode/docs/guides/phase-synchronization.md` (lines 13, 86, 265, 269, 289, 305, 314, 325, 328, 337)
  - Replace `OC_` prefix in all examples and paths
- [ ] `.opencode/docs/guides/documentation-maintenance.md` (line 133)
  - Replace `OC_NNN` with `{NNN}`
- [ ] `.opencode/docs/guides/documentation-audit-checklist.md` (lines 203, 205-211, 280)
  - Remove OC_NNN audit check
  - Update example path
- [ ] `.opencode/commands/learn.md` (lines 137, 246, 274)
  - Replace `specs/OC_{NNN}` with `specs/{NNN}`

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.opencode/context/core/standards/task-management.md`
- `.opencode/context/core/orchestration/state-management.md`
- `.opencode/context/core/patterns/metadata-file-return.md`
- `.opencode/context/core/patterns/postflight-control.md`
- `.opencode/context/core/patterns/file-metadata-exchange.md`
- `.opencode/context/core/formats/return-metadata-file.md`
- `.opencode/context/core/reference/state-management-schema.md`
- `.opencode/rules/artifact-formats.md`
- `.opencode/skills/skill-todo/SKILL.md`
- `.opencode/skills/skill-memory/SKILL.md`
- `.opencode/docs/guides/phase-synchronization.md`
- `.opencode/docs/guides/documentation-maintenance.md`
- `.opencode/docs/guides/documentation-audit-checklist.md`
- `.opencode/commands/learn.md`

**Verification**:
- Run `grep -r "OC_" .opencode/ --include="*.md" | grep -v "extensions/core" | wc -l` should return 0

---

### Phase 3: Update Extension Mirrors [COMPLETED]

**Goal**: Apply identical changes to all `.opencode/extensions/core/` mirror files.

**Tasks**:
- [ ] `.opencode/extensions/core/skills/skill-todo/SKILL.md`
  - Apply same replacements as core skill-todo
- [ ] `.opencode/extensions/core/skills/skill-memory/SKILL.md`
  - Apply same replacements as core skill-memory
- [ ] `.opencode/extensions/core/rules/artifact-formats.md`
  - Apply same replacements as core artifact-formats
- [ ] `.opencode/extensions/core/context/reference/state-management-schema.md`
  - Apply same replacements as core state-management-schema
- [ ] `.opencode/extensions/core/context/...` (all other mirrored context files)
  - Apply same replacements as their core counterparts
- [ ] `.opencode/extensions/web/skills/skill-web-research/SKILL.md`
  - Apply OC_ prefix removals per research report lines 81, 83, 112, 143, 209

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.opencode/extensions/core/skills/skill-todo/SKILL.md`
- `.opencode/extensions/core/skills/skill-memory/SKILL.md`
- `.opencode/extensions/core/rules/artifact-formats.md`
- `.opencode/extensions/core/context/reference/state-management-schema.md`
- `.opencode/extensions/core/context/patterns/*.md` (mirrored patterns)
- `.opencode/extensions/core/context/standards/*.md` (mirrored standards)
- `.opencode/extensions/core/context/guides/*.md` (mirrored guides)
- `.opencode/extensions/core/context/docs/*.md` (mirrored docs)
- `.opencode/extensions/web/skills/skill-web-research/SKILL.md`

**Verification**:
- Run `grep -r "OC_" .opencode/extensions/ --include="*.md" | wc -l` should return 0

---

### Phase 4: Final Verification and Commit [COMPLETED]

**Goal**: Ensure zero remaining references and commit changes.

**Tasks**:
- [ ] Run comprehensive grep: `grep -r "OC_" .opencode/ --include="*.md" | wc -l` (expect 0)
- [ ] Review any remaining matches manually to ensure they are false positives
- [ ] Run `git diff --stat` to review change scope
- [ ] Verify no `OC_` directories were accidentally created
- [ ] Commit with message: `task 520: remove OC_ prefix from documentation and standards`

**Timing**: 30 minutes

**Depends on**: 2, 3

**Files to modify**:
- None (verification and commit only)

**Verification**:
- Zero `OC_` references in `.opencode/` markdown files
- Git diff shows only expected changes
- Commit successful

## Testing & Validation

- [ ] No `OC_` references remain in `.opencode/` markdown files
- [ ] Bash script syntax is valid (no broken variable substitutions)
- [ ] Regex patterns compile correctly
- [ ] Extension mirrors are consistent with core files
- [ ] Git diff reviewed for accidental changes

## Artifacts & Outputs

- `specs/520_remove_oc_prefix_opencode_documentation/plans/01_oc-prefix-removal-plan.md` (this file)
- Git commit with all OC_ prefix removals
- Zero remaining `OC_` references in documentation

## Rollback/Contingency

If issues are discovered post-deployment:
1. Revert the commit: `git revert HEAD`
2. Restore from backup branch: `git checkout task-520-oc-prefix-removal-backup`
3. If only specific files are affected, cherry-pick revert of those files

## Replacement Rules Summary

| Pattern | Replacement | Applies To |
|---------|-------------|------------|
| `OC_NNN` | `{NNN}` | Display text, examples |
| `OC_017_task_slug` | `017_task_slug` | Directory examples |
| `specs/OC_${padded_num}` | `specs/${padded_num}` | Bash scripts, paths |
| `specs/OC_[0-9]*_*` | `specs/[0-9]*_*` | Bash globs |
| `sed 's/^OC_//'` | (remove line) | Bash scripts |
| `"###%s+(OC_)?(%d+)%.%s+"` | `"###%s+(%d+)%.%s+"` | Lua regex |
| `task OC_N:` | `task N:` | Commit examples |
| `### OC_{N}.` | `### {N}.` | TODO.md headers |
