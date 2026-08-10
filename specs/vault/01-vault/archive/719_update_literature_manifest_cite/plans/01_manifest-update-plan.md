# Implementation Plan: Task #719

- **Task**: 719 - Update literature extension manifest and documentation for /cite command
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: Task 717 (cite implementation, complete)
- **Research Inputs**: specs/719_update_literature_manifest_cite/reports/01_manifest-update-research.md
- **Artifacts**: plans/01_manifest-update-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Register the /cite command (implemented in task 717) in the literature extension's manifest.json, document it in EXTENSION.md, and add it to the core command reference table in merge-sources/claudemd.md. Then regenerate CLAUDE.md via the Neovim extension loader. Task 717 already created all implementation files (cite.md, skill-cite/SKILL.md, cite-extract.sh) and added skill-cite to the manifest, but did not register the command or script in provides, did not update EXTENSION.md, and did not add /cite to the core command table.

### Research Integration

Research report confirmed: (1) manifest.json needs cite.md in provides.commands and scripts/cite-extract.sh in provides.scripts; (2) EXTENSION.md has no /cite section; (3) core/merge-sources/claudemd.md has no /cite row in the command table. CLAUDE.md is auto-generated and must not be edited directly -- updating EXTENSION.md and claudemd.md is sufficient, followed by extension reload.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Register cite.md command and cite-extract.sh script in manifest.json provides
- Document /cite command workflow, arguments, and output format in EXTENSION.md
- Add /cite rows to core command reference table in merge-sources/claudemd.md
- Regenerate CLAUDE.md via extension loader

**Non-Goals**:
- Modifying cite implementation files (cite.md, SKILL.md, cite-extract.sh)
- Adding new skill-to-agent mappings (skill-cite already registered by task 717)
- Directly editing .claude/CLAUDE.md (it is auto-generated)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| manifest.json JSON syntax error after edit | H | L | Validate with jq after editing |
| CLAUDE.md not regenerated after merge-source edits | M | M | Note in plan that user must reload extension in Neovim |
| Command table formatting breaks in claudemd.md | M | L | Match exact column alignment of existing rows |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Update manifest.json [COMPLETED]

**Goal**: Register cite.md command and cite-extract.sh script in manifest provides

**Tasks**:
- [x] Add `"cite.md"` to `provides.commands` array (after `"literature.md"`) *(completed)*
- [x] Add `"scripts/cite-extract.sh"` to `provides.scripts` array (after `"scripts/zotero-search.sh"`) *(completed)*
- [x] Validate JSON syntax with `jq . manifest.json` *(completed)*

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/manifest.json` - Add cite.md to commands, cite-extract.sh to scripts

**Verification**:
- `jq '.provides.commands' manifest.json` includes `"cite.md"`
- `jq '.provides.scripts' manifest.json` includes `"scripts/cite-extract.sh"`

---

### Phase 2: Update EXTENSION.md [COMPLETED]

**Goal**: Add /cite command documentation section to the literature extension README

**Tasks**:
- [x] Add `### /cite Command` section after the existing Commands table (after line 63) *(completed)*
- [x] Include command usage table with /cite argument forms *(completed: /cite N and /cite N --gaps; N "focus" and "text" forms not in SKILL.md so not documented)*
- [x] Document workflow: extraction, search, scoring, interactive selection, task creation *(completed)*
- [x] Document citation patterns detected and output format *(completed)*

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/literature/EXTENSION.md` - Add /cite section after Commands table

**Verification**:
- EXTENSION.md contains `### /cite Command` section
- All four /cite usage forms documented
- Workflow description present

---

### Phase 3: Update core merge-sources/claudemd.md [COMPLETED]

**Goal**: Add /cite command rows to the core command reference table

**Tasks**:
- [x] Add two `/cite` rows after the `/literature --task N` row: one for task-scoped usage, one for --gaps flag *(completed)*
- [x] Match exact table column alignment of existing /literature rows *(completed)*

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/merge-sources/claudemd.md` - Add /cite rows to command table

**Verification**:
- Command table contains `/cite` entries
- Table formatting is consistent with surrounding rows

---

### Phase 4: Regenerate CLAUDE.md [COMPLETED]

**Goal**: Trigger CLAUDE.md regeneration so /cite appears in the generated output

**Tasks**:
- [x] Note to user: Open Neovim and reload the literature extension via the extension picker to regenerate CLAUDE.md *(completed: noted — CLAUDE.md is generated from merge-sources; user must reload extension)*
- [x] Verify merge-source content matches expected output *(completed: claudemd.md and EXTENSION.md both contain /cite entries)*

**Timing**: 5 minutes

**Depends on**: 2, 3

**Files to modify**:
- None directly (CLAUDE.md is auto-generated by extension loader)

**Verification**:
- After extension reload, `.claude/CLAUDE.md` contains /cite command rows and literature extension /cite section

## Testing & Validation

- [ ] `jq . .claude/extensions/literature/manifest.json` parses without error
- [ ] `grep -c "cite" .claude/extensions/literature/manifest.json` shows cite entries in commands and scripts
- [ ] EXTENSION.md contains /cite section with usage table
- [ ] claudemd.md command table contains /cite rows after /literature rows
- [ ] After Neovim extension reload, CLAUDE.md includes /cite documentation

## Artifacts & Outputs

- `specs/719_update_literature_manifest_cite/plans/01_manifest-update-plan.md` (this plan)
- Modified: `.claude/extensions/literature/manifest.json`
- Modified: `.claude/extensions/literature/EXTENSION.md`
- Modified: `.claude/extensions/core/merge-sources/claudemd.md`
- Regenerated: `.claude/CLAUDE.md` (via extension loader)

## Rollback/Contingency

All changes are to tracked files. Revert with `git checkout -- .claude/extensions/literature/manifest.json .claude/extensions/literature/EXTENSION.md .claude/extensions/core/merge-sources/claudemd.md` if implementation introduces issues.
