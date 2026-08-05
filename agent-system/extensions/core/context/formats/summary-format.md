# Summary Artifact Standard

**Scope:** Implementation summaries, plan summaries, research summaries, and project rollups produced by /implement, /plan, /research, /review, and related agents.

## Metadata (required)
- **Task**: `{id} - {title}`
- **Status**: `[NOT STARTED]` | `[IN PROGRESS]` | `[BLOCKED]` | `[ABANDONED]` | `[COMPLETED]`
- **Started**: `{ISO8601}` when summary drafting begins
- **Completed**: `{ISO8601}` when published
- **Effort**: `{estimate}` (time to produce summary)
- **Dependencies**: `{list or None}`
- **Artifacts**: list of linked artifacts summarized
- **Standards**: status-markers.md, artifact-management.md, tasks.md, this file

## Structure
1. **Overview** – 2-3 sentences on scope and context.
2. **What Changed** – bullets of key changes/deltas.
3. **Decisions** – bullets of decisions made.
4. **Impacts** – bullets on downstream effects.
5. **Follow-ups** – bullets with owners/due dates if applicable.
6. **References** – paths to artifacts informing the summary.

These six entries are the **required minimum**: a summary MUST contain all six, and MAY contain
additional sections beyond them. The gate-out validator (`validate-artifact.sh`) only reports a
*missing* required section — it never enumerates a document's headings against a whitelist — so
additional sections have never been rejected and are not an error.

### Optional Sections

- **Plan Deviations** – records plan-checklist deviations under a skipped/altered/deferred
  taxonomy, a structured concern that `## Decisions` and `## Follow-ups` do not capture on their
  own. Canonical position: after `## Decisions`, before `## Impacts`. Canonical empty value when
  no deviations occurred: `- None (implementation followed plan)`. This section is admitted as a
  named, recognized optional section because it is the dominant convention across
  implementation-terminus agents and carries this distinct structured concern — see each such
  agent's own summary-creation stage for the convention in practice.

## Writing Guidance
- Keep concise (<= 1 page).
- Use bullet lists for clarity.
- Reflect status of underlying work accurately.
- Lazy directory creation: create `summaries/` only when writing this file.

## Example Skeleton
```
# Implementation Summary: {title}
- **Task**: {id} - {title}
- **Status**: [COMPLETED]
- **Started**: 2025-12-22T10:00:00Z
- **Completed**: 2025-12-22T10:20:00Z
- **Effort**: {estimate}
- **Dependencies**: {list or None}
- **Artifacts**: plans/MM_{short-slug}.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview
...

## What Changed
- ...

## Decisions
- ...

## Plan Deviations
- None (implementation followed plan)

## Impacts
- ...

## Follow-ups
- ...

## References
- ...
```
