# Research Report: Task #374

**Task**: 374 - Update skill-founder-implement typst artifact reporting
**Started**: 2026-04-07T00:00:00Z
**Completed**: 2026-04-07T00:05:00Z
**Effort**: 0.25 hours
**Dependencies**: 373 (typst primary output restructuring, completed)
**Sources/Inputs**:
- `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md` (311 lines)
- `.claude/extensions/founder/agents/founder-implement-agent.md` (stages 6-8, metadata schema)
- `specs/373_typst_primary_output_founder_implement/plans/01_typst-primary-output.md` (completed task context)
**Artifacts**: - specs/374_update_skill_founder_implement_typst_artifacts/reports/01_typst-artifact-reporting.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The skill's postflight (section 7) blindly iterates all artifacts from the agent's metadata with no typst-awareness -- it does not distinguish primary from fallback artifacts.
- The success message (Return Format section) lists `strategy/{slug}.md` as the first report path, with typst/PDF mentioned secondarily -- this contradicts the agent's typst-primary model.
- The Expected Artifacts section references `strategy/{slug}.md` as the main report path rather than `founder/{type}-{slug}.typ`.
- A field name mismatch exists: SKILL.md references `metadata.typst_generated` but the agent writes `typst_source_generated`, `typst_cli_available`, and `pdf_compiled`.
- All changes are confined to a single file with three distinct sections to update.

## Context & Scope

Task 373 restructured `founder-implement-agent.md` to make typst the unambiguous primary output format. The agent now generates typst files first in Phase 4 and writes metadata with `typst_source_generated`, `typst_cli_available`, and `pdf_compiled` fields. However, the skill wrapper (`skill-founder-implement/SKILL.md`) was not updated to match. The skill's postflight, success messages, and expected artifacts sections still reflect the older markdown-primary model.

This research identifies exactly what needs to change and how the agent's metadata schema should drive the postflight logic.

## Findings

### 1. Current Postflight Artifact Linking (Section 7, lines 177-208)

The current postflight artifact linking is a generic loop that iterates all artifacts from the agent's return metadata:

```bash
artifacts=$(echo "$metadata" | jq '.artifacts')
for i in $(seq 0 $(($(echo "$artifacts" | jq 'length') - 1))); do
  artifact_type=$(echo "$artifacts" | jq -r ".[$i].type")
  artifact_path=$(echo "$artifacts" | jq -r ".[$i].path")
  artifact_summary=$(echo "$artifacts" | jq -r ".[$i].summary")
  # ... link each to state.json
done
```

**Issues**:
- No awareness of typst vs markdown artifacts -- all are treated identically.
- No check for `metadata.typst_source_generated` or `metadata.pdf_compiled` to determine which artifacts actually exist.
- The PDF artifact is always linked even if typst was not available (the agent includes it in the artifacts array with a conditional summary, but the skill does not filter).
- The last line of the file (line 310) says "Postflight should check `metadata.typst_generated`" but this is never implemented, and the field name is wrong (agent uses `typst_source_generated`).

**What should change**: The postflight should read `metadata.typst_source_generated`, `metadata.typst_cli_available`, and `metadata.pdf_compiled` from the metadata. It should:
- Always link the `.typ` file as the primary artifact (since typst source is always generated in Phase 4).
- Conditionally link the `.pdf` file only if `pdf_compiled` is true.
- Link the markdown file as a secondary/fallback artifact.
- Link the summary artifact as before.

### 2. Current Success Message Format (Return Format section, lines 242-283)

Two success message templates exist:

**With typst/PDF (lines 246-257)**:
```
Founder implementation completed for task {N}:
- Phases {phases_completed}/{phases_total} executed
- TAM: {tam}, SAM: {sam}, SOM Y1: {som_y1}
- Report: strategy/{slug}.md          <-- markdown listed first
- Typst/PDF: founder/{slug}.pdf       <-- typst listed second
- Summary: ...
```

**Without typst (lines 259-269)**:
```
Founder implementation completed for task {N}:
- Phases ... executed (typst/PDF skipped - not installed)
- TAM: ...
- Report: strategy/{slug}.md          <-- only markdown shown
- Summary: ...
```

**Issues**:
- The "with typst" variant lists the markdown report first (`Report: strategy/{slug}.md`) and typst second, contradicting typst-primary.
- The typst line only shows the PDF, not the `.typ` source file.
- The "without typst" variant only shows the markdown path with no mention of the `.typ` source (which is always generated regardless of typst CLI availability).

**What should change**:
- With typst/PDF: Show `founder/{type}-{slug}.typ` as primary, `founder/{type}-{slug}.pdf` as compiled output, `strategy/{type}-{slug}.md` as fallback.
- Without typst CLI: Show `founder/{type}-{slug}.typ` as primary source, note PDF was skipped, show markdown as fallback.

### 3. Expected Artifacts Section (implicit in Return Format and Error Handling)

The expected artifacts are embedded in the Return Format examples rather than a dedicated section. The current paths shown:
- `strategy/{slug}.md` -- presented as the main "Report" path
- `founder/{slug}.pdf` -- presented as secondary "Typst/PDF" path
- `specs/{NNN}_{SLUG}/summaries/01_{short-slug}-summary.md` -- summary

**What the agent actually produces** (from agent metadata schema, lines 1004-1024):
1. `founder/{report-type}-{slug}.typ` -- Typst source (primary, always generated)
2. `founder/{report-type}-{slug}.pdf` -- PDF (conditional on typst CLI)
3. `strategy/{report-type}-{slug}.md` -- Markdown (fallback)
4. `specs/{NNN}_{SLUG}/summaries/01_{short-slug}-summary.md` -- Summary

**Issues**:
- The SKILL.md artifact paths use `{slug}` while the agent uses `{report-type}-{slug}`.
- The `.typ` source file is not mentioned in the SKILL.md expected artifacts at all.
- The ordering does not reflect typst-primary.

### 4. Agent Metadata Schema (reference for postflight implementation)

The agent writes these relevant metadata fields (lines 1036-1041):
```json
{
  "typst_source_generated": true,
  "typst_cli_available": true,
  "pdf_compiled": true,
  "pdf_path": "founder/{report-type}-{slug}.pdf"
}
```

And these artifact entries (lines 1004-1024):
```json
{
  "artifacts": [
    {"type": "implementation", "path": "founder/{report-type}-{slug}.typ", "summary": "Typst source file (primary)"},
    {"type": "implementation", "path": "founder/{report-type}-{slug}.pdf", "summary": "PDF report (conditional)"},
    {"type": "implementation", "path": "strategy/{report-type}-{slug}.md", "summary": "Markdown report (fallback)"},
    {"type": "summary", "path": "specs/.../summaries/01_...-summary.md", "summary": "Implementation summary"}
  ]
}
```

The postflight should use `metadata.typst_source_generated` and `metadata.pdf_compiled` to filter which artifacts are linked in state.json and which paths are displayed in the success message.

### 5. Field Name Mismatch

Line 310 of SKILL.md:
> Postflight should check `metadata.typst_generated` to determine what artifacts to report.

The agent uses `typst_source_generated`, not `typst_generated`. This must be corrected.

## Decisions

- The postflight artifact linking logic must become typst-aware rather than being a blind loop.
- The success message must show typst source path first, PDF second (if compiled), markdown as fallback.
- Artifact path templates must use `{report-type}-{slug}` to match the agent's actual output pattern.
- The `metadata.typst_generated` reference must be corrected to `metadata.typst_source_generated`.

## Recommendations

1. **Rewrite Section 7 postflight** to read `metadata.typst_source_generated` and `metadata.pdf_compiled` before linking artifacts. Filter out the PDF artifact entry if `pdf_compiled` is false. Always link the `.typ` file first as primary.

2. **Rewrite Return Format section** with three templates:
   - With PDF: typst source (primary) -> PDF (compiled) -> markdown (fallback)
   - Without PDF (typst not installed): typst source (primary, always generated) -> markdown (fallback) -> note about installing typst
   - Partial (core failure): unchanged

3. **Fix the Error Handling reference** on line 310 to use `metadata.typst_source_generated` instead of `metadata.typst_generated`, and add references to `metadata.pdf_compiled`.

4. **Update artifact path examples** throughout SKILL.md from `strategy/{slug}.md` to `founder/{report-type}-{slug}.typ` as primary, with PDF companion and markdown fallback.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agent metadata schema changes in future | Postflight breaks if field names change | Low | Use the same field names documented in agent's Stage 7 |
| Blind artifact loop removal breaks edge cases | Missing artifacts in state.json | Low | Keep loop for summary artifacts, add explicit typst/PDF/markdown handling |
| Path template mismatch with actual agent output | Wrong paths in success messages | Low | Use exact path patterns from agent metadata schema |

## Appendix

### Files requiring changes

1. `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md`
   - Section 7: Postflight Status Update (lines 177-208)
   - Return Format section (lines 242-283)
   - Error Handling section, line 310

### Key metadata fields from agent

| Field | Type | Description |
|-------|------|-------------|
| `typst_source_generated` | boolean | Whether .typ file was written in Phase 4 |
| `typst_cli_available` | boolean | Whether typst CLI was found on system |
| `pdf_compiled` | boolean | Whether PDF was successfully compiled |
| `pdf_path` | string | Path to compiled PDF file |

### Agent artifact order (from Stage 7 metadata)

1. `founder/{report-type}-{slug}.typ` -- primary, always generated
2. `founder/{report-type}-{slug}.pdf` -- conditional on typst CLI + compilation success
3. `strategy/{report-type}-{slug}.md` -- fallback, always generated
4. `specs/{NNN}_{SLUG}/summaries/01_{short-slug}-summary.md` -- always generated
