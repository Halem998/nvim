# Implementation Plan: Task #910

- **Task**: 910 - Fix roadmap-integration.sh reporting success while annotating nothing
- **Status**: [COMPLETED]
- **Effort**: 5.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/910_fix_roadmap_annotation_silent_noop/reports/01_roadmap-annotation-silent-noop.md
- **Artifacts**: plans/01_roadmap-annotation-signal.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`roadmap-integration.sh` finds a valid table-row completion match and then fails to apply it,
because the annotation loop unconditionally constructs checkbox syntax (`- [ ] {item}`) that
cannot exist in a checkbox-free table roadmap. The script exits 0 with a success-shaped payload,
and its sole consumer surfaces only `annotations_made`, so the failure is invisible. This plan
(1) plumbs a source-line reference from parser through matcher to annotator so table-row matches
can be rewritten in place, (2) adds an always-on machine-readable structure marker plus loud
banners and additive JSON fields so a no-op can never masquerade as success, and (3) extends the
one consumer that reads the payload so the new signal actually reaches the user.

### Research Integration

Key findings carried into this plan:

- Root cause is confirmed at `roadmap-integration.sh:482-483` (unconditional checkbox
  `OLD_LINE`), with the dead `"source": "status_table"` field at line 429 as corroborating
  evidence of an incomplete migration.
- The parser (lines 215-220) captures **no** line number or raw line text for table rows, so the
  annotator has nothing to locate. The fix therefore spans parser + matcher + annotator, not one
  line.
- `literature-briefing.sh` supplies a reusable two-part precedent: an always-present
  machine-readable HTML-comment marker plus a conditional loud bracketed banner.
- `/review` (`agent-system/extensions/core/commands/review.md`) is the **only** consumer of this
  script's payload. It extracts only `annotations_made`; `items_skipped` and `skipped_reasons`
  are computed and dropped. `/todo` never calls this script at all.

**One deliberate refinement of the research's proposed condition for signal (b).** The research
(and the task description) name the unparseable condition as `phases == 0 && checkboxes == 0`.
After Phase 1-3 land, a table-only roadmap has exactly that shape *and is fully annotatable* — so
that literal condition would fire a false alarm on precisely the case this task fixes. This plan
therefore splits the signal in two:

| Signal | Condition | Meaning |
|--------|-----------|---------|
| `unparseable_roadmap` | `phases == 0 && checkboxes == 0 && table_rows == 0` | No recognized structure of any supported kind |
| `annotation_noop` | annotate mode ran, `high_confidence_matches > 0`, `annotations_made == 0` | Structure recognized, matches found, nothing applied |

Together these cover strictly more ground than the single literal condition, and neither fires
spuriously on a working table roadmap. The three counts are always emitted regardless, so a
consumer can reconstruct the literal condition if it ever wants to.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists in this repository and uses the `## Phase N:` heading + `- [ ]`
checkbox format. No roadmap item corresponds to this defect fix, so this plan advances no
roadmap item. The file is, however, a valuable **regression fixture**: it is the exact format the
existing checkbox path already handles, so Phase 5 uses a copy of it to prove the checkbox path
is unchanged. This plan does not modify `specs/ROADMAP.md`.

## Goals & Non-Goals

**Goals**:

- Table-row matches with `confidence == "high"` are located and annotated in place, preserving
  the row's pipe-delimited structure, with the completion marker appended to the same status cell
  the allowlist matched.
- The checkbox annotation path is byte-for-byte behaviourally unchanged.
- The script always emits a machine-readable roadmap-structure marker and, when warranted, a loud
  banner in the established `[SPARSE COVERAGE ...]` / `[UNVERIFIED ...]` family.
- New diagnostics are exposed as **JSON fields**, not stderr only, because the sole consumer
  parses specific JSON fields and would otherwise ignore a stderr-only signal.
- All JSON changes are strictly additive: no existing field is removed, renamed, or retyped.
- `/review` surfaces the new signal in the review report and the commit message, so
  `Roadmap: 0 items annotated` can no longer mean three different things.

**Non-Goals**:

- Changing the phase-header regex (`^## Phase (\d+): ...`) or otherwise broadening heading
  recognition. Explicitly out of scope per the task's scope boundary.
- Reformatting any project's `ROADMAP.md`.
- Touching `/todo`'s independent, prose-level roadmap reimplementation in
  `skill-todo/SKILL.md` (Stages 5 and 11). It never calls this script; see Follow-Ups.
- Editing `.claude/scripts/roadmap-integration.sh` or `.opencode/scripts/roadmap-integration.sh`.
  Both are disposable deploy artifacts regenerated from the source store.
- Adding a permanent test-suite file to the repository (no such harness exists for this script;
  verification uses task-scoped throwaway fixtures under `specs/`).

## Scope Decision: Declared file_scope Expansion

The task's declared `file_scope` is exactly one file:
`agent-system/extensions/core/scripts/roadmap-integration.sh`.

**Decision: expand `file_scope` by exactly one file** —
`agent-system/extensions/core/commands/review.md` — implemented in a single isolated phase
(Phase 6) that touches no other file.

**Rationale**:

1. The task description itself requires it: *"confirm how /todo and /review consume the payload,
   so that whichever signal is chosen is actually surfaced to the user rather than swallowed by
   the caller."* Surfacing is an in-task requirement, not an add-on.
2. The defect being fixed *is* the silence. Research established that `review.md` currently drops
   `items_skipped` and `skipped_reasons` on the floor. Fixing only the script would reproduce the
   identical silence one layer up — the letter of `file_scope` satisfied, the goal missed.
3. The edit is small (extract fields, render a warning line, extend a commit-message template)
   and purely additive to a markdown command definition.
4. Isolating it in the final phase keeps it independently revertible: reverting Phase 6 alone
   returns the change set to the originally declared `file_scope` with the script fix intact.

**Alternative considered and rejected**: scoping the `review.md` edit as a follow-up
recommendation. Rejected because it ships a diagnostic that no consumer reads — a signal that
exists in the payload and reaches no user is the same defect class this task exists to close.

The implementer MUST record this expansion explicitly in the implementation summary and in
`state.json`'s `modified_files`, never silently.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Captured line indices go stale mid-run | H | L | Every annotation is a strict 1-line-for-1-line replacement, so line numbers never shift within a run. Phase 3 additionally re-verifies the on-disk line at the captured index equals the captured raw line before writing; a mismatch is a recorded skip (`table_row_line_mismatch`), never a blind write. |
| Cell-rewrite corrupts a pipe table (wrong cell, lost columns, mangled escaping) | H | M | Reconstruct the line from exactly the same regex/split the parser used (`^\|(.*)\|(\s*)$` then `.split('|')`), mutate only the captured `status_index` cell, and rejoin. Phase 5 asserts column count and all non-target cells are unchanged. |
| Regression in the existing checkbox path | H | L | Phase 3 branches on `.source == "status_table"`; the checkbox branch keeps its existing `OLD_LINE`/`NEW_LINE`/`awk` code path unmodified. Phase 5 runs a copy of this repo's own checkbox-format `specs/ROADMAP.md` as a regression fixture. |
| Additive JSON fields break an undiscovered consumer | M | L | Research grep-confirmed `review.md` is the only consumer in the source store. Changes are additive only; existing field names, types, and nesting are untouched. |
| Two rows with identical component text collide | M | M | Location is by `(line_index, raw_line)` pair, not by component text. Component text is no longer used for locating anything on the table path. |
| Banner false-positives on a healthy table roadmap | M | M | The refined two-signal condition above; `unparseable` requires `table_rows == 0` as well. Phase 5 explicitly asserts no banner fires on the table-only fixture. |
| Scope creep beyond the one declared expansion | M | M | Phase 6 is the only phase permitted to touch a file other than the script, and only `review.md`. Any further consumer work is listed under Follow-Ups, not implemented. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |

Phases within the same wave can execute in parallel. This plan is fully sequential by design:
Phases 1-5 all edit the same single file, so parallel execution would create write conflicts on
shared territory; Phase 6 depends on the payload schema being final and verified.

### Phase 1: Capture Table-Row Source References in the Parser [COMPLETED]

**Goal**: Make each `status_tables` entry carry enough information to locate and safely rewrite
its originating line later. Today it carries only derived cell values.

**Tasks**:
- [x] In the Step 2.5 python parser (`roadmap-integration.sh`, table-row branch, around the
      `status_tables.append({...})` call), capture the loop's existing `i` as `line_index`
      (0-based, matching `lines`). *(completed)*
- [x] Capture the unmodified source line as `raw_line`. *(completed)*
- [x] Capture the column index chosen as the status column as `status_index`: set it inside the
      existing `for c in cols[1:]` allowlist scan (use `enumerate(cols[1:], start=1)` or track the
      index alongside), and fall back to `1` on the same branch where `status` already falls back
      to `cols[1]`. Record `null` only when there is genuinely no column to point at. *(completed)*
- [x] Leave every existing key (`component`, `status`, `location`, `columns`) unchanged in name,
      order, and value. *(completed)*
- [x] Add a short comment stating why the reference is captured: the annotator cannot locate a
      table row from derived cell values alone. *(completed)*

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - Step 2.5 python parser,
  table-row `status_tables.append` block and the status-column scan directly above it.

**Verification**:
- Run the script without `--annotate` against `specs/ROADMAP.md` and against a table-format
  fixture; confirm every `status_tables[]` entry now has `line_index`, `raw_line`, and
  `status_index`.
- Confirm `roadmap_state.status_tables[].raw_line` matches the corresponding
  `sed -n "$((line_index+1))p"` of the source file for a spot-checked sample.
- Confirm `phases` output is unchanged versus a pre-change run on the same input.

---

### Phase 2: Propagate the Source Reference Through the Matcher [COMPLETED]

**Goal**: Carry the new reference from `status_tables` into each table-sourced match object so
the annotator does not have to re-derive it.

**Tasks**:
- [x] In the Step 2.5.2 python table-row loop, add `line_index`, `raw_line`, and `status_index`
      to the appended match object, alongside the existing `"source": "status_table"`. *(completed)*
- [x] Leave the checkbox-path match objects entirely unchanged (they have no `source` key today;
      keep it that way so `.source // ""` cleanly distinguishes the two paths downstream).
      *(completed)*
- [x] Add a comment noting that `"source"` was previously dead and is now load-bearing for the
      Step 2.5.3 branch. *(completed)*

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - Step 2.5.2 python matcher,
  table-row `matches.append` block.

**Verification**:
- Run without `--annotate` against a table fixture; confirm each element of `roadmap_matches`
  with `source == "status_table"` carries all three new fields with non-null values.
- Confirm checkbox-sourced match objects still have exactly their original key set.

---

### Phase 3: Source-Aware Annotation of Table Rows [COMPLETED]

**Goal**: Make Step 2.5.3 branch on match source and rewrite a matched table row in place,
preserving its pipe structure, instead of searching for a checkbox line that cannot exist.

**Tasks**:
- [x] Extract `SOURCE`, `LINE_INDEX`, `RAW_LINE`, and `STATUS_INDEX` from each match via `jq -r`,
      alongside the existing `ITEM_TEXT`/`TASK_NUM`/`COMPLETION_DATE` extraction. Use
      `.source // ""` so checkbox matches yield an empty string. *(completed)*
- [x] Keep the annotation-suffix construction (`*(Completed: Task N, DATE)*` / `*(Completed: Task
      N)*`) exactly where it is, as the single source of truth for the marker format used by both
      branches. *(completed)*
- [x] **Checkbox branch (`SOURCE` empty)**: leave the existing `OLD_LINE`/`NEW_LINE`/`awk`/`diff`
      logic unmodified. *(completed: byte-identical to pre-task baseline, verified against
      `specs/ROADMAP.md`)*
- [x] **Table branch (`SOURCE == "status_table"`)**: *(completed)*
  - [x] Replace the `grep -F "$ITEM_TEXT" | head -1` already-annotated heuristic with a precise
        check: read the on-disk line at `LINE_INDEX + 1`; if it contains `*(Completed:`, count it
        as `already_annotated` and continue. Component text is never used to locate a line.
        *(completed)*
  - [x] If the on-disk line at `LINE_INDEX + 1` does not equal `RAW_LINE`, skip with new reason
        `table_row_line_mismatch` (stale reference / file changed underneath) and continue.
        Never write on a mismatch. *(completed: guard wired and code-reviewed; unreachable in a
        single run per this same phase's own verification note, accepted as defensive)*
  - [x] Build the replacement line with a small `python3` invocation that mirrors the parser's own
        parse: match `^\|(.*)\|(\s*)$`, `split('|')` the inner text, append
        ` {ANNOTATION_SUFFIX}` to the `STATUS_INDEX` cell (preserving that cell's leading
        whitespace and its trailing single space), rejoin with `|`, and re-append the captured
        trailing whitespace. Column count must be identical before and after. *(completed:
        verified on 3-, 4-, and 5-column fixtures)*
  - [x] Apply with `awk -v ln=... -v old=... -v new=...` replacing only the line where
        `NR == ln && $0 == old`, writing to a temp file and `mv`-ing on change, mirroring the
        existing checkbox apply. *(completed)*
  - [x] On no-change, record the new reason `table_row_not_found_at_line` rather than the
        misleading `line_not_found_exact`. *(completed)*
- [x] **Fix the dry-run over-report on both branches**: today `--dry-run` increments
      `ANNOTATIONS_MADE` without confirming the target line exists, so a dry run reports success
      for edits that would fail. Gate the dry-run increment on the same existence check the apply
      path performs (exact-line presence for checkboxes; `LINE_INDEX`/`RAW_LINE` agreement for
      table rows), and print a `[dry-run] would skip: {reason}` line otherwise. *(completed)*
- [x] Make the dry-run and success stderr messages source-aware so a table-row annotation is
      distinguishable from a checkbox annotation in the transcript. *(completed: "(checkbox)" /
      "(table row)" tags on every dry-run and applied-annotation message)*
- [x] Document the invariant in a comment: every annotation replaces exactly one line with
      exactly one line, so captured `line_index` values remain valid for the whole annotate loop.
      *(completed)*

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - Step 2.5.3 annotation loop
  (extraction, already-annotated check, old/new line construction, apply, skip accounting,
  dry-run branch).

**Verification**:
- `--dry-run` against a table fixture prints a table-shaped proposed replacement, not
  `- [ ] {component}`.
- `--annotate` against the same fixture rewrites the intended row: same column count, only the
  status cell changed, marker appended.
- Re-running `--annotate` on the now-annotated fixture yields `annotations_made: 0` with
  `already_annotated` (idempotence), not a duplicate marker.
- `--annotate` against a checkbox fixture produces the identical result as before this phase.
- A fixture whose table row was deliberately edited between parse and annotate is not reachable
  in one run; instead assert the mismatch branch by unit-checking it with a hand-built match
  object, or accept the guard as defensive and note it as such.

---

### Phase 4: Roadmap-Structure Marker, Banners, and Additive JSON Fields [COMPLETED]

**Goal**: Make the script incapable of reporting a silent no-op, via an always-on structured
marker, conditional loud banners, and JSON fields the consumer can read.

**Tasks**:
- [x] After `ROADMAP_STATE` is computed, derive three counts with `jq`: `phases | length`,
      `[.phases[].checkboxes.total] | add // 0`, and `.status_tables | length`. *(completed)*
- [x] Emit an always-present machine-readable marker to stderr, mirroring the
      `literature-briefing.sh` convention:
      `<!-- roadmap-structure phases=N checkboxes=M table_rows=T parseable=true|false -->`.
      Emit it unconditionally, in every mode, including parse-only. *(completed)*
- [x] When `phases == 0 && checkboxes == 0 && table_rows == 0`, emit a loud banner in the
      established family:
      `[UNPARSEABLE ROADMAP - 0 phases, 0 checkboxes, 0 table rows]` plus one actionable sentence
      naming the two structures the parser recognizes. *(completed)*
- [x] Compute `high_confidence_matches` (the existing `MATCH_COUNT`) and hoist it so it is
      available for the JSON payload even when `--annotate` was not passed (0 in that case).
      *(completed)*
- [x] When annotate mode ran and `high_confidence_matches > 0` and `ANNOTATIONS_MADE == 0`, emit
      a second loud banner:
      `[ROADMAP ANNOTATION NO-OP - {K} high-confidence match(es), 0 applied]` followed by the
      distinct skip reasons. *(completed)*
- [x] Extend the output JSON, additively only: *(completed)*
  - [x] New top-level `roadmap_structure`: `{phases, checkboxes, table_rows, parseable}`.
        *(completed)*
  - [x] New top-level `warnings`: array of stable string codes, drawn from
        `unparseable_roadmap` and `annotation_noop`; `[]` when neither applies. *(completed)*
  - [x] New `annotation_summary.high_confidence_matches` (int) and
        `annotation_summary.silent_noop` (bool). *(completed)*
  - [x] Verify `roadmap_state`, `roadmap_matches`, `annotation_summary.annotations_made`,
        `.items_skipped`, and `.skipped_reasons` are untouched in name, type, and nesting.
        *(completed: verified via jq type checks across 5 fixture scenarios)*
- [x] Update the script's header comment block (the `Output schema:` section) to document the new
      fields and the two warning codes. *(completed)*

**Timing**: 1 hour

**Depends on**: 3

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - post-`ROADMAP_STATE` count
  block, annotate-loop tail, final `jq -n` assembly, header comment block.

**Verification**:
- Parse-only run on any roadmap prints the `<!-- roadmap-structure ... -->` marker.
- Unstructured fixture (no phases, no checkboxes, no tables) emits the `[UNPARSEABLE ROADMAP ...]`
  banner, sets `roadmap_structure.parseable: false`, and includes `unparseable_roadmap` in
  `warnings`.
- Working table fixture emits **no** banner and `warnings: []`.
- Fixture engineered to match but fail application yields `annotation_noop` in `warnings` and
  `annotation_summary.silent_noop: true`.
- `jq` on the full payload confirms all pre-existing field paths still resolve with their original
  types.

---

### Phase 5: Fixture-Based End-to-End Verification [COMPLETED]

**Goal**: Prove all four behaviours (table annotation, checkbox regression, unparseable banner,
no-op banner) against real inputs, and record the evidence.

**Tasks**:
- [x] Create throwaway fixtures under
      `specs/910_fix_roadmap_annotation_silent_noop/fixtures/` (task-scoped artifacts, not
      deliverables — nothing is added to the repository's permanent test surface): *(completed)*
  - [x] `checkbox-roadmap.md` — a copy of this repository's `specs/ROADMAP.md` (regression
        baseline for the untouched checkbox path). *(completed)*
  - [x] `table-roadmap.md` — a checkbox-free roadmap with a status table containing at least one
        row whose status cell reads `Complete (task N)` and at least one still-in-progress row,
        plus one 4-column and one 5-column table to exercise the column-agnostic parser.
        *(completed: also includes a deliberate component-text collision -- two "Widget Driver"
        rows across the two tables -- to exercise the by-(line_index, raw_line) location
        guarantee)*
  - [x] `unstructured-roadmap.md` — headings only, no `## Phase N:`, no checkboxes, no tables.
        *(completed)*
  - [x] `fixture-state.json` — a minimal `state.json` with completed tasks matching the fixture
        rows by explicit `(task N)` reference. *(completed)*
- [x] Capture a pre-change baseline: run the current committed script against
      `checkbox-roadmap.md` and save the payload for byte comparison. *(completed: baseline taken
      from the pre-task commit of `roadmap-integration.sh`)*
- [x] Run the matrix: each fixture x {parse-only, `--dry-run`, `--annotate`}; save stdout payloads
      and stderr transcripts. *(completed: 9 runs under fixtures/matrix-output/, all exit 0)*
- [x] Assert, per the per-phase verification criteria above: table row annotated in place with
      identical column count and only the status cell changed; checkbox payload matches the
      baseline; unparseable banner fires only on the unstructured fixture; no-op banner fires only
      on the engineered failure case; idempotence on a second `--annotate`. *(completed — see
      implementation summary for the full matrix and assertions)*
- [x] Confirm the script still exits 0 in all cases (banners are diagnostics, not failures) and
      that `set -euo pipefail` is not tripped by the new code, including on an empty
      `status_tables`. *(completed)*
- [x] Record the matrix and its outcomes in the implementation summary. *(completed)*

**Timing**: 1 hour

**Depends on**: 4

**Files to modify**:
- `specs/910_fix_roadmap_annotation_silent_noop/fixtures/*` - new task-scoped fixtures (created,
  not modifications to any deliverable).

**Verification**:
- All matrix assertions pass and are transcribed into the summary.
- `git status` shows no unintended modification to `specs/ROADMAP.md` or to any file under
  `.claude/` or `.opencode/`.

---

### Phase 6: Surface the Signal in /review (DECLARED FILE_SCOPE EXPANSION) [COMPLETED]

**Goal**: Make the new diagnostics reach the user. This is the single, explicitly declared
expansion beyond the task's original `file_scope`; see "Scope Decision" above.

**Tasks**:
- [x] In `review.md` Section 2.5, extend the extraction block to also capture
      `roadmap_structure`, `warnings`, `annotation_summary.items_skipped`,
      `annotation_summary.skipped_reasons`, `annotation_summary.high_confidence_matches`, and
      `annotation_summary.silent_noop`. *(completed)*
- [x] Extend the existing empty-state fallback (both the script-missing and the non-zero-exit
      branches) to also default the new variables, so the fallback path stays well-formed.
      *(completed)*
- [x] Add an explicit warning emission: when `warnings` is non-empty, echo each code with a
      human-readable expansion to stderr during the review run, so it is visible in the
      transcript rather than only in the report. *(completed, verified end-to-end against both
      the engineered no-op fixture and the unstructured fixture)*
- [x] In the review report template's `## Roadmap Progress` section, add a **Roadmap Signal**
      subsection rendered when `warnings` is non-empty or `roadmap_structure.parseable` is false:
      state the counts, the warning codes, and the distinct `skipped_reasons`. Update the
      accompanying note (which currently directs population from `roadmap_state` and
      `roadmap_matches`) to cover the new subsection. *(completed)*
- [x] Extend the commit-message template so `Roadmap: {annotations_made} items annotated` is
      disambiguated — append the skipped count and, when present, the warning codes, so
      "nothing to do", "N matches all failed to apply", and "structure unrecognized" are
      distinguishable at a glance. *(completed)*
- [x] Do not introduce any task-number citation into `review.md` (it lives outside `specs/**`).
      Reference behaviours and field names, never task numbers. *(completed for all content
      added by this phase; a single pre-existing citation from prior, unrelated work remains at
      one line outside every section this phase touched -- out of this phase's declared scope,
      noted in the implementation summary rather than silently fixed or silently left
      unmentioned)*

**Timing**: 45 minutes

**Depends on**: 5

**Files to modify**:
- `agent-system/extensions/core/commands/review.md` - Section 2.5 extraction and fallback blocks,
  the review report template's `## Roadmap Progress` section and its trailing note, and the
  Section 7 git commit-message template.

**Verification**:
- Every new JSON field consumed in `review.md` exists in the Phase 4 payload, checked field name
  by field name against a captured fixture payload.
- Both fallback branches define every variable the downstream template references (no unbound
  variable under `set -u` semantics in the documented snippets).
- Grep confirms `review.md` contains no `task N` / `tasks N-M` citation.
- The implementation summary records this file as a declared `file_scope` expansion with its
  rationale.

---

## Testing & Validation

- [ ] Table-row match with `confidence: high` is annotated in place; column count unchanged; only
      the allowlist-matched status cell modified.
- [ ] Second `--annotate` run on an already-annotated roadmap is a clean no-op reported as
      `already_annotated`, with no duplicate marker.
- [ ] Checkbox path payload is byte-identical to the pre-change baseline on the checkbox fixture.
- [ ] `<!-- roadmap-structure ... -->` marker is present on every invocation, in every mode.
- [ ] `[UNPARSEABLE ROADMAP ...]` fires only when phases, checkboxes, and table rows are all zero.
- [ ] `[ROADMAP ANNOTATION NO-OP ...]` fires only when high-confidence matches exist and none
      applied.
- [ ] All pre-existing JSON field paths resolve with unchanged types; changes are additive only.
- [ ] `--dry-run` no longer reports an annotation it could not actually apply.
- [ ] Script exits 0 in all fixture scenarios; banners never change the exit code.
- [ ] `bash -n agent-system/extensions/core/scripts/roadmap-integration.sh` passes.
- [ ] No file under `.claude/` or `.opencode/` is modified.
- [ ] No task-number citation appears in either modified deliverable file.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/roadmap-integration.sh` - modified (parser, matcher,
  annotator, structure signal, header schema docs)
- `agent-system/extensions/core/commands/review.md` - modified (declared `file_scope` expansion)
- `specs/910_fix_roadmap_annotation_silent_noop/fixtures/` - task-scoped verification fixtures
- `specs/910_fix_roadmap_annotation_silent_noop/summaries/01_roadmap-annotation-signal-summary.md`
  - implementation summary, including the verification matrix and an explicit statement of the
  `file_scope` expansion

## Follow-Ups (not implemented here)

- `/todo` (`agent-system/extensions/core/skills/skill-todo/SKILL.md`, Stages 5 and 11)
  independently reimplements roadmap matching and annotation in prose and never calls this
  script. It is unaffected by every change in this plan. Consolidating the two implementations,
  or at minimum having `/todo` call this script, is a separate task worth creating.
- The phase-header regex recognizes only `## Phase N: Title` headings. Broadening it is
  explicitly out of scope here, but the new `roadmap_structure` counts make the limitation
  visible for the first time, which is the natural precondition for deciding whether to address
  it.

## Rollback/Contingency

- Every change is confined to two tracked files plus task-scoped fixtures. `git checkout` of the
  two files restores prior behaviour completely; no state migration, no schema removal, nothing
  persisted outside the working tree.
- Phase 6 is isolated: reverting it alone returns the change set to the originally declared
  `file_scope` while keeping the script fix.
- JSON changes are additive, so a partial rollback (script reverted, `review.md` kept) degrades
  to the consumer reading absent fields — mitigated because Phase 6 defines fallback defaults for
  every new variable.
- If the cell-rewrite proves unsafe on real-world tables during Phase 5, fall back to appending
  the marker to the end of the row (before the closing pipe) rather than into a specific cell,
  and record the deviation in the summary. Do not abandon the line-reference plumbing — it is the
  prerequisite for either approach.
