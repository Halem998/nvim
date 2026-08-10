# Research Report: Task #375

**Task**: 375 - Update founder command docs typst paths
**Started**: 2026-04-07T00:00:00Z
**Completed**: 2026-04-07T00:05:00Z
**Effort**: 30 minutes
**Dependencies**: Task 373 (typst primary output implementation)
**Sources/Inputs**:
- Codebase: 6 founder command files in `.claude/extensions/founder/commands/`
- Task 373 context (typst as primary output format)
**Artifacts**:
- `specs/375_update_founder_command_docs_typst_paths/reports/01_founder-command-typst-paths.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- All 6 founder command files contain `.md` output path references that need updating to `.typ` (Typst primary) with `.md` fallback noted
- Each file has exactly 3 categories of references to update: (1) the "Note" about `/implement` output, (2) legacy mode artifact paths, and (3) workflow summary diagram output paths
- The sheet.md file is slightly different -- it references `.pdf` output instead of `.md`, and should reference `.typ` primary with `.pdf` as the compiled output
- Legacy mode (`--quick`) artifact paths reference `founder/` directory with `.md` extension; these should also be updated to `.typ` primary
- Total: 18 distinct references across 6 files need updating

## Context & Scope

Task 373 established Typst (`.typ`) as the primary output format for founder extension artifacts, with markdown (`.md`) as a fallback. This task updates the 6 founder command documentation files to reflect that change. The `/deck` command is excluded as it uses Slidev.

Files in scope:
- `.claude/extensions/founder/commands/market.md`
- `.claude/extensions/founder/commands/analyze.md`
- `.claude/extensions/founder/commands/strategy.md`
- `.claude/extensions/founder/commands/legal.md`
- `.claude/extensions/founder/commands/finance.md`
- `.claude/extensions/founder/commands/sheet.md`

## Findings

### Per-File Reference Inventory

#### 1. market.md

| Location | Current Reference | Update To |
|----------|------------------|-----------|
| Line 454 (Note) | `strategy/market-sizing-*.md` | `strategy/market-sizing-*.typ` (primary), `.md` fallback |
| Line 384 (Legacy artifact) | `founder/market-sizing-{datetime}.md` | `founder/market-sizing-{datetime}.typ` |
| Line 459 (Legacy table) | `founder/market-sizing-{datetime}.md` | `founder/market-sizing-{datetime}.typ` |
| Line 473 (Workflow diagram) | `generates strategy/market-sizing-*.md` | `generates strategy/market-sizing-*.typ` |

#### 2. analyze.md

| Location | Current Reference | Update To |
|----------|------------------|-----------|
| Line 423 (Note) | `strategy/competitive-analysis-*.md` | `strategy/competitive-analysis-*.typ` (primary), `.md` fallback |
| Line 366 (Legacy artifact) | `founder/competitive-analysis-{datetime}.md` | `founder/competitive-analysis-{datetime}.typ` |
| Line 429 (Legacy table) | `founder/competitive-analysis-{datetime}.md` | `founder/competitive-analysis-{datetime}.typ` |
| Line 443 (Workflow diagram) | `generates strategy/competitive-analysis-*.md` | `generates strategy/competitive-analysis-*.typ` |

#### 3. strategy.md

| Location | Current Reference | Update To |
|----------|------------------|-----------|
| Line 437 (Note) | `strategy/gtm-strategy-*.md` | `strategy/gtm-strategy-*.typ` (primary), `.md` fallback |
| Line 377 (Legacy artifact) | `founder/gtm-strategy-{datetime}.md` | `founder/gtm-strategy-{datetime}.typ` |
| Line 443 (Legacy table) | `founder/gtm-strategy-{datetime}.md` | `founder/gtm-strategy-{datetime}.typ` |
| Line 455 (Workflow diagram) | `generates strategy/gtm-strategy-*.md` | `generates strategy/gtm-strategy-*.typ` |

#### 4. legal.md

| Location | Current Reference | Update To |
|----------|------------------|-----------|
| Line 466 (Note) | `strategy/contract-analysis-*.md` | `strategy/contract-analysis-*.typ` (primary), `.md` fallback |
| Line 397 (Legacy artifact) | `founder/contract-analysis-{datetime}.md` | `founder/contract-analysis-{datetime}.typ` |
| Line 471 (Legacy table) | `founder/contract-analysis-{datetime}.md` | `founder/contract-analysis-{datetime}.typ` |
| Line 484 (Workflow diagram) | `generates strategy/contract-analysis-*.md` | `generates strategy/contract-analysis-*.typ` |

#### 5. finance.md

| Location | Current Reference | Update To |
|----------|------------------|-----------|
| Line 481 (Note) | `strategy/financial-analysis-*.md` | `strategy/financial-analysis-*.typ` (primary), `.md` fallback |
| Line 410 (Legacy artifact) | `founder/financial-analysis-{datetime}.md` | `founder/financial-analysis-{datetime}.typ` |
| Line 487 (Legacy table) | `founder/financial-analysis-{datetime}.md` | `founder/financial-analysis-{datetime}.typ` |
| Line 499 (Workflow diagram) | `generates strategy/financial-analysis-*.md` | `generates strategy/financial-analysis-*.typ` |

#### 6. sheet.md

| Location | Current Reference | Update To |
|----------|------------------|-----------|
| Line 463 (Note) | `strategy/cost-analysis-*.pdf` | `strategy/cost-analysis-*.typ` (primary, compiles to PDF) |
| Line 379-380 (Legacy artifacts) | `founder/cost-breakdown-{datetime}.xlsx` + `founder/cost-metrics-{datetime}.json` | Keep XLSX/JSON (data artifacts), add `.typ` report |
| Line 469-470 (Legacy table) | `founder/cost-breakdown-{datetime}.xlsx` + `founder/cost-metrics-{datetime}.json` | Keep XLSX/JSON, add `.typ` |
| Line 482 (Workflow diagram) | `generates strategy/cost-analysis-*.pdf` | `generates strategy/cost-analysis-*.typ` (compiles to PDF) |

### Pattern for Updates

Each "Note" line should follow this pattern:

**Current pattern**:
```
**Note**: Full {report type} (`strategy/{name}-*.md`) is generated by `/implement`, not `/{command}`.
```

**Updated pattern**:
```
**Note**: Full {report type} (`strategy/{name}-*.typ`, with `.md` fallback) is generated by `/implement`, not `/{command}`.
```

Each workflow diagram line should follow this pattern:

**Current pattern**:
```
/implement {N}          -> Executes plan, generates strategy/{name}-*.md
```

**Updated pattern**:
```
/implement {N}          -> Executes plan, generates strategy/{name}-*.typ
```

Legacy mode artifacts should update `.md` to `.typ`:

**Current pattern**:
```
| {Report type} | `founder/{name}-{datetime}.md` |
```

**Updated pattern**:
```
| {Report type} | `founder/{name}-{datetime}.typ` |
```

### Special Case: sheet.md

The sheet.md file is unique because:
1. It already references `.pdf` instead of `.md` for the final output (line 463)
2. It produces XLSX and JSON data artifacts that should remain unchanged
3. The `.pdf` reference should become `.typ` (primary) noting it compiles to PDF
4. Legacy XLSX/JSON artifacts are data files, not reports -- keep their extensions

## Decisions

- **Update scope**: All 3 reference categories (Note, Legacy artifact, Workflow diagram) in all 6 files
- **Fallback notation**: Use parenthetical `(with .md fallback)` in the Note lines only, not in workflow diagrams or legacy tables (too verbose)
- **sheet.md PDF**: Update `.pdf` to `.typ` in the Note and workflow diagram; the PDF is a compilation target, not a source format
- **Legacy XLSX/JSON**: Keep unchanged -- these are data artifacts, not typst-replaceable documents
- **Legacy .md artifacts**: Update to `.typ` since legacy mode should also use the new primary format

## Risks & Mitigations

- **Risk**: Legacy `--quick` mode may still generate `.md` files if the underlying skills haven't been updated
  - **Mitigation**: Documentation update is independent of runtime behavior; skill updates are a separate task
- **Risk**: Users referencing old paths in workflows
  - **Mitigation**: The `.md` fallback notation makes the transition clear

## Appendix

### Files examined
- `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/market.md` (497 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/analyze.md` (466 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/strategy.md` (480 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/legal.md` (509 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/finance.md` (524 lines)
- `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/sheet.md` (507 lines)

### Reference to task 373
Task 373 established Typst as the primary output format for the founder extension. This task (375) is a documentation follow-up to align command files with that change.
