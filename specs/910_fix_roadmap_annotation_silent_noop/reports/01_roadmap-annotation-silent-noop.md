# Research Report: Task #910

**Task**: 910 - fix_roadmap_annotation_silent_noop
**Started**: 2026-07-26
**Completed**: 2026-07-26
**Effort**: Medium (two independent, well-bounded fixes)
**Dependencies**: None
**Sources/Inputs**: Codebase read of `agent-system/extensions/core/scripts/roadmap-integration.sh` (548 lines, full read), `agent-system/extensions/core/commands/review.md`, `agent-system/extensions/core/skills/skill-todo/SKILL.md`, `agent-system/extensions/literature/scripts/literature-briefing.sh` (banner-pattern precedent)
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Root cause confirmed and is exactly what the task description hypothesized**: the table-row completion matcher (added to fix an earlier defect) finds a valid match, but the *annotation-application* code was never updated to handle table-row-sourced matches. It unconditionally builds `OLD_LINE="- [ ] $ITEM_TEXT"` (checkbox syntax) and searches for an exact-text line match, which can never exist for a match whose source line is a markdown table row (`| Component | complete | ... |`). The `awk` diff finds no change, and the item is recorded as skipped with `line_not_found_exact`.
- The `roadmap_matches` entries produced by the table-row path already carry a `"source": "status_table"` field specifically meant to distinguish them from checkbox-origin matches — but that field is **never read** anywhere in the Step 2.5.3 annotation loop (`roadmap-integration.sh:456-514`). It is dead/unused, which is strong corroborating evidence this is an incomplete migration, not a deliberate design choice.
- A second, independent problem exists at the phase-header parser (`roadmap-integration.sh:133`, hard-coded `^## Phase (\d+): ...$`), which explains `phases: 0` for the downstream roadmap. This did **not** cause the observed `annotations_made: 0` in this specific run (the one match came from the phase-independent table-row matcher), but it is a second, real source of silent data loss for any roadmap using different heading conventions with checkbox items nested under them.
- Recommendation: **(c) both** — fix the line-lookup for table-row matches (a), AND add a loud, machine-readable "unparseable roadmap" signal (b). They fix two different failure modes (a match found but misapplied vs. no structure recognized at all) and are both small, targeted changes.
- **Consumption finding (important, changes framing of "confirm how /todo and /review consume the payload")**: `/review` is the *only* consumer of `roadmap-integration.sh`'s JSON payload. `/todo` does **not** call this script at all — `skill-todo/SKILL.md` Stage 5 ("ScanRoadmap") and Stage 11 ("UpdateRoadmap") reimplement roadmap matching/annotation independently, in prose, as agent-executed steps. A fix to `roadmap-integration.sh` will not reach `/todo`'s roadmap handling; that is a separate, undocumented code path with its own (unverified in this research pass) behavior.
- Within `/review`, the payload is consumed but weakly: `annotations_made` is extracted and appears only in a git commit message line (`Roadmap: {annotations_made} items annotated`); `items_skipped` and `skipped_reasons` are computed by the script but **never extracted or read** by `review.md` at all. `roadmap_state.phases` feeds the "Current Focus" table in the review report — which silently renders empty/missing when `phases: 0`, another visible symptom of the same underlying silence.

## Context & Scope

Investigated `agent-system/extensions/core/scripts/roadmap-integration.sh` (the SOURCE-STORE copy; per repo convention this is the file to edit — `.claude/scripts/roadmap-integration.sh` is a gitignored deploy artifact) end to end, plus its two known callers (`review.md` and, for completeness, `skill-todo/SKILL.md`, which turned out not to be a caller). Reproduced the reasoning behind the observed downstream payload (`phases: 0`, `matches: 1`, `annotations_made: 0`, `skipped_reasons: ["line_not_found_exact"]`) by tracing code paths rather than re-running against the downstream file (out of scope / not available in this repo).

## Findings

### Codebase Patterns

**File structure of `roadmap-integration.sh` (548 lines total):**
- Lines 113-233: Step 2.5 — python parser. Builds `ROADMAP_STATE = {phases: [...], status_tables: [...]}`.
  - Line 133: phase-header regex `^## Phase (\d+): (.+?)(?:\s+\((\w+ Priority)\))?$` — matches only `## Phase N: Title (Priority)` headings. The downstream roadmap's headings (`## Overview`, `## BX Axiom System`, `### Layer 1: Propositional (4)`) never match this, so `phases: []` for that file, regardless of table content.
  - Lines 167-220: generic pipe-table row parser (column-count-agnostic, per an earlier fix documented in the file's own comments) producing `status_tables` entries shaped `{component, status, location, columns}`. **Critically, no line number or raw source line is captured for a table row** — only derived cell values. This matters for fix (a) below.
- Lines 284-434: Step 2.5.2 — python matcher (`ROADMAP_MATCHES`). Two independent loops feed a single `matches` list:
  - Lines 364-391: checkbox-item loop (only over `phase["checkboxes"]["items"]`, so it contributes nothing when `phases == []`).
  - Lines 393-430: **table-row loop** (`roadmap-integration.sh:399-430`), added specifically because "ROADMAP.md's current table format has zero checkboxes... without this loop annotations_made is always 0" (its own inline comment, line 397-398). For each `status_tables` row whose status column matches `STATUS_ALLOWLIST_RE` (`\b(complete|resolved|done)\b`), it runs the shared `find_match()` heuristic and, on match, appends an entry with `"source": "status_table"` (line 429) and `roadmap_item` set to **only the component-name cell** (`row.get("component", "")`, line 422) — not the full row text, not the status cell, not a line reference.
- Lines 447-524: Step 2.5.3 — bash annotation loop, applied only to `confidence == "high"` matches (line 453).
  - Lines 458-460: extracts `ITEM_TEXT`, `TASK_NUM`, `COMPLETION_DATE` from each match via `jq -r`. **Never extracts `.source`.**
  - Lines 482-483: unconditionally builds
    ```bash
    OLD_LINE="- [ ] $ITEM_TEXT"
    NEW_LINE="- [x] $ITEM_TEXT $ANNOTATION_SUFFIX"
    ```
    This is checkbox-format-only. For a `status_table`-sourced match, `ITEM_TEXT` is just the component name (e.g. `Foo Bar`), so `OLD_LINE` becomes the literal string `- [ ] Foo Bar` — a line that does not exist anywhere in a checkbox-free roadmap.
  - Lines 492-501: `awk` does an exact `$0 == old` line replacement into a temp file.
  - Lines 503-512: if `diff -q` shows no change (i.e., the constructed `OLD_LINE` was never found), the item is counted as `ITEMS_SKIPPED` with reason `line_not_found_exact` (line 506) — **exactly the observed downstream symptom**, for exactly the reason the task description predicted ("finds a match and then fails to locate the line to annotate").
  - Lines 528-548: JSON is always assembled and printed; the script's own exit code (via `set -euo pipefail`) is unaffected by `ANNOTATIONS_MADE == 0` — there is no code path that treats "matched but couldn't annotate anything" or "0 phases and 0 checkboxes" as anything other than ordinary success.

**Consumer 1 — `/review` (`agent-system/extensions/core/commands/review.md`):**
- Section "2.5. Roadmap Integration" (lines 67-99) is the only place in the repo that invokes `roadmap-integration.sh`.
- It captures `roadmap_exit` explicitly (a documented earlier fix, per its own comment, against jq-on-empty-input masking failures) and falls back to an empty default only when the script is *missing* or *exits non-zero* or *produces empty output* — none of which occur in the observed defect (the script exits 0 with well-formed JSON).
- Of the JSON payload, only `annotations_made` is pulled forward past this section (line 84); it surfaces exactly once, in the commit message template at line 791: `Roadmap: {annotations_made} items annotated`. `annotations_made: 0` and `annotations_made: 0` because the roadmap genuinely had nothing to do look identical in this line — there is no distinguishing signal.
- `annotation_summary.items_skipped` and `annotation_summary.skipped_reasons` (which would show `["line_not_found_exact"]`) are **never extracted or referenced anywhere in `review.md`**. This is the concrete mechanism of the "silent" in the task title: the script computes the diagnostic, but the sole caller drops it on the floor.
- `roadmap_state.phases` feeds the review report's "Current Focus" table (line 275: "Use `roadmap_state.phases` to build the Current Focus table"). With `phases: []`, this table would render empty (or be omitted) with no accompanying explanation — a second, independent visible symptom of the same root state.

**Consumer 2 (expected but not actual) — `/todo` (`agent-system/extensions/core/skills/skill-todo/SKILL.md`):**
- Grepped for `roadmap-integration`, `roadmap_output`, `annotation_summary` inside `skill-todo/SKILL.md`: **zero matches.**
- Stage 5 "ScanRoadmap" (lines 189-212) and Stage 11 "UpdateRoadmap" (lines 753-763) describe roadmap matching and annotation in prose, executed directly by the agent (reading `specs/ROADMAP.md`, matching completed/abandoned tasks, applying `- [x] item *(Completed: Task {N}, DATE)*` / `- [ ] item *(Task {N} abandoned: reason)*` annotations) — a **separate, independent reimplementation** of roughly the same logic, not a call into `roadmap-integration.sh`.
- Consequence for this task: fixing `roadmap-integration.sh` improves `/review`'s behavior only. `/todo`'s roadmap annotation path is untouched by any fix here and was not otherwise investigated (out of scope — the task names `roadmap-integration.sh` as the sole file_scope). This divergence (two independent implementations of "annotate ROADMAP.md from completed tasks") is worth flagging to the user/planner as a follow-up observation, not something to fix under this task's file_scope.

### External Resources

**Existing "loud banner" precedent in this codebase**, directly reusable as a template for signal (b): `agent-system/extensions/literature/scripts/literature-briefing.sh` implements the sparse-coverage pattern named in the task description:
- Emits an always-present, machine-readable HTML-comment marker line unconditionally:
  `<!-- lit-coverage mode=repo|global seg_count=N sparse=true|false threshold=T -->` (line 415)
- Emits a loud, human-visible bracketed banner **only when the condition is true**:
  `[SPARSE COVERAGE - N segment(s), threshold T] ...` (line 419), with actionable next-step text.
- This two-part shape (always-on structured marker + conditional loud banner) is exactly the "same family as `[SPARSE COVERAGE ...]` / `[UNVERIFIED ...]`" the task asks for, and gives a ready-made naming/format convention to mirror rather than invent from scratch.

### Recommendations

**Recommendation: implement both (a) and (b).** They are independent, address different failure surfaces, and are each small:

**(a) Fix the table-row annotation line-lookup.** Concretely, this requires touching two of the three python/bash stages, not just Step 2.5.3, because the parser currently discards the information needed to locate a table row's original line:
1. **Parser (Step 2.5, ~`roadmap-integration.sh:200-220`)**: when appending a `status_tables` entry, also capture something that lets the annotator find the exact source line later — e.g. the row's 0- or 1-based `line_index` (the parser already iterates `for i, line in enumerate(lines)`, so `i` is available for free) and/or the raw original line text. Line-index is likely more robust than the checkbox path's exact-text match, since table rows with identical status text (e.g. many rows all saying `complete`) are far more likely to collide on text than full checkbox sentences are.
2. **Matcher (Step 2.5.2, ~`roadmap-integration.sh:418-430`)**: propagate that line reference into the match object alongside the existing `"source": "status_table"` field, so Step 2.5.3 doesn't have to re-derive it.
3. **Annotator (Step 2.5.3, ~`roadmap-integration.sh:456-514`)**: branch on `.source == "status_table"` (extract it via `jq -r`, mirroring the existing `ITEM_TEXT`/`TASK_NUM`/`COMPLETION_DATE` extraction at lines 458-460). For table-row matches, locate the target line by the captured line index (or, if line-index plumbing proves too invasive for this pass, at minimum match on the *full original row text*, not just the component-name cell) and construct a `NEW_LINE` that preserves the row's pipe-delimited structure while appending the `*(Completed: Task N, DATE)*` marker to the matched status cell (the same cell `STATUS_ALLOWLIST_RE` matched in Step 2.5.2) rather than trying to force a checkbox-shaped replacement. The existing "skip if already annotated" and one-edit-per-item safety rules (lines 442-445, 462-472) should extend naturally to this path — they're already source-agnostic except for the exact-string assumptions.
4. This is a genuine, non-trivial code change (touches parser + matcher + annotator), not a one-line fix — size accordingly in planning.

**(b) Emit a loud, machine-readable "unparseable roadmap" signal.** Add this near the end of Step 2.5 (right after `ROADMAP_STATE` is computed, `roadmap-integration.sh:234`) or in the final JSON assembly (lines 526-548):
1. Compute `phase_count = len(phases)` and `total_checkboxes = sum(p["checkboxes"]["total"] for p in phases)` (trivially 0 when `phase_count == 0`, but keep both named for clarity/future-proofing) — this is the exact condition named in the task description ("0 phases AND 0 checkboxes").
2. Emit an always-present marker, mirroring the literature precedent's naming convention, e.g.:
   `<!-- roadmap-structure phases=N checkboxes=M unparseable=true|false -->`
3. When `unparseable=true`, emit a loud banner to stderr, e.g.:
   `[UNPARSEABLE ROADMAP - 0 phases, 0 checkboxes] ROADMAP.md does not match the expected "## Phase N: Title" heading + "- [ ] item" checkbox structure; phase-based progress tracking and checkbox annotation are unavailable for this file.`
4. **Also add this as a structured field in the JSON payload itself** (e.g. `annotation_summary.roadmap_parseable: false`, or a top-level `warnings: [...]` array) — not only a stderr banner — because the stderr-only precedent in `literature-briefing.sh` is consumed by an agent reading the whole tool transcript, whereas `review.md` explicitly parses only specific JSON fields out of `roadmap_output` (lines 81-84) and would otherwise silently ignore a stderr-only signal exactly the way it currently ignores `skipped_reasons`.
5. This signal is independent of whether any `matches` were found — it fires purely on structural roadmap shape, so it also covers the "0 matches, 0 phases, 0 checkboxes" case that (a) alone would not address.

**Required companion change (from the task's own instruction to "confirm ... the signal is actually surfaced")**: `review.md` Section 2.5 (lines 67-99) must be extended to extract the new field(s) — both `annotation_summary.items_skipped`/`skipped_reasons` (already computed today, just unread) and the new parseability signal from (b) — and do something visible with them: at minimum, include a warning line in the review report's "## Roadmap Progress" section when `phases: []`/`roadmap_parseable == false`, and extend the commit-message template (line 791) so `Roadmap: 0 items annotated` cannot masquerade as "nothing to do" when it actually means "N candidate matches found, all failed to apply" or "roadmap structure unrecognized." Without this companion change, fixing the script alone reproduces the exact same silence one layer up.

## Decisions

- Recommend (c) — both (a) and (b) — over doing only one, because they cover disjoint failure modes: (a) fixes "a match was found but couldn't be written" (the specific 1-match downstream case); (b) fixes "nothing could even be attempted" (0 phases, 0 checkboxes, 0 matches — a distinct, plausible case for other downstream roadmaps not investigated here). Neither alone closes both gaps.
- Treat `/todo`'s independent roadmap-annotation reimplementation (`skill-todo/SKILL.md` Stages 5/11) as an explicit **out-of-scope finding**, not a silent gap in this report: the task's `file_scope` names only `roadmap-integration.sh`, and `/todo` never calls it, so no code change under this task's scope will affect `/todo`'s behavior. Flagging this for the user/planner to decide whether a follow-up task is warranted.
- Do not attempt to fix or comment on the phase-header regex's downstream-format mismatch (`## Overview`, `### Layer 1: ...` vs `## Phase N: ...`) beyond noting it as a parser limitation — per the task's explicit SCOPE BOUNDARY, whether any given ROADMAP.md should be reformatted is that project's decision, not this task's.

## Risks & Mitigations

- **Risk**: Line-index-based table row lookup (recommended in (a)) could still mis-locate a row if `ROADMAP.md` is concurrently edited between the parse pass and the annotate pass, or if annotating an earlier row shifts line numbers for a later one within the same run. **Mitigation**: apply the same "one edit per item, re-derive nothing across edits" discipline already used for checkboxes (the loop processes one match at a time and writes to a temp file before `mv`); if line-index tracking is used, either (i) annotate table rows in reverse line order within a single pass so earlier shifts don't affect later ones, or (ii) re-derive the target line via full-row-text exact match (safer, more consistent with the existing checkbox pattern) with line-index only as a disambiguator when multiple rows have identical text.
- **Risk**: Adding a new JSON field (`roadmap_parseable` / `warnings`) is a payload schema change; any other undiscovered consumer of `roadmap-integration.sh` output could be affected. **Mitigation**: the research confirmed via grep that `review.md` is the only consumer in the source store; an additive (never removing/renaming existing fields) JSON change is backward compatible with it.
- **Risk**: Scope creep into fixing the phase-header regex or `/todo`'s separate implementation. **Mitigation**: explicitly out of scope per the task description and per `file_scope`; called out above as findings only.

## Context Extension Recommendations

None — this is a task-specific script defect; no gap in `.claude/context/` documentation was identified.

## Appendix

- Searches: `grep -rn "roadmap-integration.sh"` across `agent-system/`; `grep -rln "annotation_summary"`; `grep -n "roadmap" skill-todo/SKILL.md`; `grep -rln "SPARSE COVERAGE|lit-coverage|UNVERIFIED"` across `agent-system/` to locate the existing banner-pattern precedent.
- Full read of `agent-system/extensions/core/scripts/roadmap-integration.sh` (548 lines).
- Read of `agent-system/extensions/core/commands/review.md` lines 55-150 and 740-803 (Section 2.5 Roadmap Integration, Section 7 Git Commit, Section 4.5 Update Review State / Roadmap Progress notes).
- Read of `agent-system/extensions/core/skills/skill-todo/SKILL.md` lines 175-260 and 740-763 (Stage 5 ScanRoadmap, Stage 11 UpdateRoadmap).
- Read of `agent-system/extensions/literature/scripts/literature-briefing.sh` lines 405-420 (sparse-coverage marker + banner precedent).
