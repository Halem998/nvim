# Implementation Plan: Task #747

- **Task**: 747 - Evaluate Zotero CLI tools for shell-first integration
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/747_evaluate_zotero_cli_tools/reports/01_zotero-cli-eval.md
- **Artifacts**: plans/01_zotero-cli-eval.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general
- **Lean Intent**: false

## Overview

This task is research-only: the deliverable is a finalized comparison matrix and recommendation document, not code. The research report has already identified zotero-cli-cc as the primary backend recommendation, with detailed findings on both candidates. The implementation phases cover verifying the recommended tool installs and works, polishing the comparison matrix into a standalone format, and writing the final recommendation document that downstream tasks (Zotero extension creation) can reference.

### Research Integration

The research report (01_zotero-cli-eval.md) provides comprehensive findings:
- zotero-cli-cc recommended as primary backend (offline SQLite reads, stable JSON envelope, agent-optimized output)
- zotero-mcp evaluated as secondary option (richer features but requires Zotero running, no offline mode)
- Detailed comparison matrix across 25+ criteria
- NixOS installation analysis (uv tool install preferred)
- Risks and mitigations identified

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the broader Zotero integration effort. The "Literature centralization" roadmap item (Phase 2, completed) established the foundation; this evaluation informs the next step of building a shell-first Zotero extension.

## Goals & Non-Goals

**Goals**:
- Verify zotero-cli-cc installs and responds to basic commands
- Finalize the comparison matrix in a clean, reference-ready format
- Produce a self-contained recommendation document suitable for downstream task consumption

**Non-Goals**:
- Building the Zotero extension (separate future task)
- Writing wrapper scripts or shell integrations
- Configuring Web API keys or testing write operations
- Evaluating MCP server mode in depth

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| zotero-cli-cc fails to install via uv on NixOS | H | L | Fall back to pipx; document both paths |
| zot command requires Zotero data directory that does not exist on test machine | M | M | Use --help and version checks as smoke test; note if data dir needed for full validation |
| Research findings are already complete enough that implementation adds little value | L | M | Focus implementation on verification and formatting rather than duplicating research |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Verify Installation and Smoke Test [COMPLETED]

**Goal**: Confirm zotero-cli-cc installs cleanly and responds to basic commands, validating the research recommendation.

**Tasks**:
- [x] Check if `uv` is available on the system *(completed: uv 0.11.19 found at /run/current-system/sw/bin/uv)*
- [x] Run `uv tool install zotero-cli-cc` (or verify it is already installed) *(completed: installed v0.7.0, newer than v0.4.3 in research)*
- [x] Run `zot --version` to confirm installation *(completed: returns "zot, version 0.7.0")*
- [x] Run `zot --help` to verify command surface matches research findings *(completed: confirms search, read, note, pdf, attach, tag, export, collection, stats, list)*
- [x] Run `zot search --help` to confirm SQLite read path is available *(completed: confirmed, includes --collection, --type, --sort, --stream flags)*
- [x] Document any installation issues or deviations from research findings *(completed: default data dir is ~/Zotero not ~/Documents/Zotero; use ZOT_DATA_DIR env var to override)*
- [x] If Zotero data directory exists, run `zot search "test"` as a live smoke test *(completed: ZOT_DATA_DIR=/home/benjamin/Documents/Zotero zot search "modal logic" returns 3 results with stable JSON envelope; library has 880 items, 870 PDFs, 18 notes; note/attach dry-runs confirmed)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- No source files modified; this is a verification phase

**Verification**:
- `zot --version` returns a version string
- `zot --help` output confirms documented command surface (search, read, note, pdf, attach, tag)

---

### Phase 2: Finalize Recommendation Document [COMPLETED]

**Goal**: Produce the final comparison matrix and recommendation document as a polished, self-contained artifact that downstream Zotero extension tasks can reference.

**Tasks**:
- [x] Create the final recommendation document at `specs/747_evaluate_zotero_cli_tools/summaries/01_zotero-cli-eval-summary.md` *(completed)*
- [x] Include a clean comparison matrix table (refined from research report, focusing on criteria most relevant to extension development) *(completed: 25-row matrix with child attachment column added)*
- [x] Include a "Recommended Architecture" section describing the primary + optional secondary tool approach *(completed)*
- [x] Include a "Getting Started" section with exact installation commands for NixOS *(completed: uv, ZOT_DATA_DIR, config init steps)*
- [x] Include an "API Key Setup" section for write operations *(completed)*
- [x] Include a "Command Quick Reference" table for the most important zot commands *(completed: search, PDF, notes, attach, tags/collections)*
- [x] Record any installation issues or deviations discovered in Phase 1 *(completed: v0.7.0 vs v0.4.3, ZOT_DATA_DIR requirement, expanded command surface)*
- [x] Cross-reference the research report for detailed findings *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `specs/747_evaluate_zotero_cli_tools/summaries/01_zotero-cli-eval-summary.md` - New file: final recommendation document

**Verification**:
- Summary document exists and contains: comparison matrix, recommendation, installation instructions, command reference
- Document is self-contained (readable without the research report)
- All claims are consistent with research report findings

## Testing & Validation

- [ ] zotero-cli-cc installs successfully via uv or pipx
- [ ] zot --version and --help return expected output
- [ ] Final recommendation document is complete and self-contained
- [ ] Comparison matrix covers all critical evaluation criteria
- [ ] No contradictions between recommendation document and research report

## Artifacts & Outputs

- `specs/747_evaluate_zotero_cli_tools/plans/01_zotero-cli-eval.md` (this plan)
- `specs/747_evaluate_zotero_cli_tools/summaries/01_zotero-cli-eval-summary.md` (final recommendation document)

## Rollback/Contingency

This is a documentation-only task. If implementation reveals that zotero-cli-cc does not work as documented, update the recommendation to reflect actual findings rather than reverting. The research report remains as the detailed reference regardless.
