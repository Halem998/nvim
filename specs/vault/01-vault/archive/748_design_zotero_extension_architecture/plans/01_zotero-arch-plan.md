# Implementation Plan: Task #748 - Design Zotero Extension Architecture

- **Task**: 748 - Design Zotero extension architecture
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: Task 747 (completed)
- **Research Inputs**: specs/748_design_zotero_extension_architecture/reports/01_zotero-extension-arch.md
- **Artifacts**: plans/01_zotero-arch-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This task produces a single architecture design document that synthesizes the research from task 748 into a concrete, implementable specification for the Zotero extension. The research report identified the two-tier data model (Zotero SQLite as global source, per-repo `specs/zotero-index.json` as relevance filter), the `zot` CLI backend, a 9-script architecture across 5 categories, the `/zotero` command surface with 10 sub-modes, the `--zot` context injection flag, and a weighted multi-field retrieval scoring algorithm. The plan's output is a design document that can directly drive downstream implementation tasks (749-753).

### Research Integration

The research report (01_zotero-extension-arch.md) provides comprehensive findings across 10 sections: literature extension template analysis, CLI tool selection, `--lit` implementation analysis, per-repo index schema (18 fields), chunk storage model, retrieval scoring algorithm (6 fields with weights), manifest and routing, 9-script architecture in 5 categories, `/zotero` command surface, and context injection hook integration. All findings will be synthesized into the design document with concrete specifications suitable for implementation.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

ROADMAP.md exists but no `roadmap_flag` was set. No roadmap phases are added.

## Goals & Non-Goals

**Goals**:
- Produce a comprehensive architecture design document at `specs/748_design_zotero_extension_architecture/summaries/01_zotero-arch-design.md`
- Specify every component with sufficient detail for an implementation agent to build it without ambiguity
- Define the complete extension manifest.json schema with all fields
- Specify the per-repo `specs/zotero-index.json` schema with field-level documentation
- Document all 9 scripts with inputs, outputs, exit codes, and error handling
- Specify the `/zotero` command argument parsing and sub-mode dispatch
- Define the `--zot` flag integration into `command-route-skill.sh`
- Specify the retrieval scoring algorithm with pseudocode
- Document coexistence strategy with `--lit` and `--clean` flags

**Non-Goals**:
- Writing any implementation code (scripts, manifest, extension files)
- Creating the downstream tasks 749-753 (those are assumed to already exist or will be created separately)
- Modifying any existing extension or script files
- Building or testing the Zotero integration

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Design document too long for single-agent implementation | M | L | Structure document with clear section boundaries so phases can reference specific sections |
| Research findings incomplete for some script specifications | M | L | Flag gaps explicitly in the design document with "TBD" markers rather than inventing details |
| Coexistence with --lit may have edge cases not covered in research | L | M | Document known interaction matrix; flag unknowns for resolution during implementation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Create Architecture Design Document [COMPLETED]

**Goal**: Synthesize the research report into a structured, implementable architecture specification document.

**Tasks**:
- [x] Create `specs/748_design_zotero_extension_architecture/summaries/01_zotero-arch-design.md` *(completed)*
- [x] Write Section 1: Overview and Design Principles -- two-tier model explanation, design goals, constraints, and relationship to the literature extension *(completed)*
- [x] Write Section 2: Extension Manifest Schema -- complete `manifest.json` with all fields documented (name, version, dependencies, routing_exempt, provides, merge_targets, keyword_overrides, hooks) *(completed)*
- [x] Write Section 3: Directory Layout -- full tree of `.claude/extensions/zotero/` with file purposes *(completed)*
- [x] Write Section 4: Per-Repo Index Schema -- `specs/zotero-index.json` with every field documented (type, required/optional, purpose, default value, example), including top-level fields (version, created, last_updated, token_budget, zot_data_dir) and entry-level fields (18 fields) *(completed)*
- [x] Write Section 5: Script Architecture -- all 9 scripts organized by category with: synopsis, arguments, environment variables, stdin/stdout contracts, exit codes (0=success, 1=error, 2=not-configured), dependencies on other scripts *(completed)*
  - [x] Category A: CLI Wrappers (zotero-read.sh, zotero-write.sh, zotero-setup.sh) *(completed)*
  - [x] Category B: Chunk Management (zotero-chunk.sh, zotero-attach-chunks.sh, zotero-index-add.sh) *(completed)*
  - [x] Category C: Index Management (zotero-index-remove.sh, zotero-search-index.sh) *(completed)*
  - [x] Category D: Context Injection (zotero-retrieve.sh) *(completed)*
- [x] Write Section 6: Retrieval Scoring Algorithm -- weighted multi-field scoring formula, per-field scoring rules, minimum threshold, domain-term boosting, token budget management, pseudocode in both prose and jq *(completed)*
- [x] Write Section 7: Command Surface -- `/zotero` with all 10 sub-modes, argument parsing, dispatch table, error handling per sub-mode *(completed)*
- [x] Write Section 8: Flag Integration -- `--zot` flag parsing in `command-route-skill.sh`, interaction matrix with `--lit`, `--clean`, `--hard`, `--team`; context injection order (memory -> literature -> zotero) *(completed)*
- [x] Write Section 9: Coexistence Strategy -- how `--zot` and `--lit` coexist, when to use which, overlap in `specs/literature/` for chunk storage, no mutual exclusion *(completed)*
- [x] Write Section 10: Downstream Task Map -- which sections of this document drive which implementation tasks (749-753), with dependency ordering *(completed)*
- [x] Write Section 11: Configuration and Setup -- `ZOT_DATA_DIR` detection, `zot` installation check, Web API key handling, graceful degradation *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `specs/748_design_zotero_extension_architecture/summaries/01_zotero-arch-design.md` - Create new architecture design document

**Verification**:
- Document exists and contains all 11 sections
- Each script has synopsis, arguments, exit codes, and dependencies documented
- The per-repo index schema has all 18 entry fields plus top-level fields documented
- The retrieval scoring algorithm includes both prose description and pseudocode
- The `/zotero` command surface covers all 10 sub-modes
- The flag interaction matrix is complete

---

### Phase 2: Verify Completeness and Cross-Reference Consistency [COMPLETED]

**Goal**: Review the design document for internal consistency, verify all research findings are accounted for, and ensure the document is self-contained for downstream implementation.

**Tasks**:
- [x] Cross-reference every finding in the research report against the design document -- ensure no research section was omitted *(completed: all 10 research sections have corresponding coverage)*
- [x] Verify script dependency chains are consistent (e.g., zotero-chunk.sh calls zotero-read.sh and literature-chunk.sh -- both must be documented) *(completed: all dependencies documented)*
- [x] Verify the manifest.json `provides.scripts` array matches the 9 scripts documented in Section 5 *(completed: exact match)*
- [x] Verify the command surface sub-modes each have a clear script dispatch target *(completed: all 10 sub-modes have dispatch targets in Section 7)*
- [x] Verify the flag interaction matrix covers all 5 flag combinations (bare, --zot, --lit, --zot --lit, --clean --zot) *(completed: matrix covers 10 combinations including all required)*
- [x] Verify the downstream task map (Section 10) covers all 5 implementation tasks and their dependency ordering *(completed: tasks 749-753 with dependency chain)*
- [x] Add any missing cross-references or clarifications found during review *(completed: no gaps found)*

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `specs/748_design_zotero_extension_architecture/summaries/01_zotero-arch-design.md` - Edit to add any missing content found during verification

**Verification**:
- All 10 research report sections have corresponding coverage in the design document
- No script references an undocumented dependency
- The manifest `provides.scripts` list matches the documented scripts exactly
- The downstream task map has no gaps

## Testing & Validation

- [x] Design document contains all 11 sections with substantive content (not stubs) *(completed)*
- [x] Per-repo index schema has all 18 entry-level fields documented with types and purposes *(completed: 20 fields including 2 timestamp fields)*
- [x] All 9 scripts have synopsis, arguments, exit codes, and dependency documentation *(completed)*
- [x] Retrieval scoring algorithm has both prose and pseudocode *(completed)*
- [x] Flag interaction matrix covers all combinations *(completed)*
- [x] Downstream task map references tasks 749-753 with correct scope boundaries *(completed)*
- [x] No "TBD" markers remain (or if they do, they are explicitly flagged as intentional gaps) *(completed: no TBD markers)*

## Artifacts & Outputs

- `specs/748_design_zotero_extension_architecture/plans/01_zotero-arch-plan.md` (this file)
- `specs/748_design_zotero_extension_architecture/summaries/01_zotero-arch-design.md` (primary deliverable)

## Rollback/Contingency

This is a documentation-only task. If the design document is unsatisfactory, it can be revised via `/revise 748` or overwritten by re-running `/implement 748`. No code changes are made, so no rollback is needed.
