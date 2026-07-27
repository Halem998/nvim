# Implementation Plan: Task #914

- **Task**: 914 - converge_todo_roadmap_annotation_with_script
- **Status**: [IMPLEMENTING]
- **Effort**: 6 hours
- **Dependencies**: None
- **Research Inputs**: specs/914_converge_todo_roadmap_annotation_with_script/reports/01_todo-roadmap-annotation-convergence.md
- **Artifacts**: plans/01_converge-todo-roadmap-annotation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`/todo` maintains two independently-authored roadmap-annotation specifications
(`commands/todo.md`, `skills/skill-todo/SKILL.md`), neither of which calls
`roadmap-integration.sh`. Both can report a clean archival pass while annotating zero roadmap
items, because both instruct the executor to *omit* the roadmap section when no matches were
found — making "found nothing" indistinguishable from "nothing to do". This plan implements the
research report's option (b): `roadmap-integration.sh` becomes `/todo`'s single parser and signal
source (invoked parse-only, then again with `--annotate` against a filtered snapshot), while
`/todo` retains the two things the shared script structurally cannot do — abandoned-task
annotation and meta/expanded exclusion. Definition of done: a roadmap that parses to zero phases,
zero checkboxes, and zero table rows is never reportable by `/todo` as a successful annotation
pass, in either spec, in both dry-run and final output.

### Research Integration

The report's findings drive the whole design and are adopted, with one correction and two
implementation constraints the report did not surface:

- **Adopted**: option (b) with the parse-only reuse mechanism; the two genuine requirement
  differences (abandoned annotation, meta/expanded exclusion) confirmed absent from the script by
  grep; `/review`'s consumer block in `commands/review.md` as the reference pattern for error
  handling, fallback defaults, and warning surfacing.
- **Correction (verified live, this repo)**: the report states the live `ROADMAP.md` is
  table-based with zero checkboxes, making `/todo`'s matcher "structurally guaranteed" to produce
  zero annotations. Running the script parse-only against this repository returns
  `phases=2 checkboxes=12 table_rows=0 parseable=true`. The report inherited that claim from a
  comment inside `roadmap-integration.sh` describing a different corpus. The recommendation is
  unaffected — `/todo`'s matcher is still checkbox-only and table-blind, and the silent-success
  defect is real independent of which shape the file currently has — but no phase below may be
  written as though checkbox matching is dead code.
- **Constraint A (sequencing, not in the report)**: `commands/todo.md`'s Step 5.5 runs *after*
  Step 5 archival. By then the archived tasks have been removed from `active_projects` and
  inserted into `specs/archive/state.json`. An `--annotate` call pointed at the live
  `specs/state.json` at that point would therefore see none of the tasks being archived. The
  filtered snapshot must be synthesized from the eligible-task list captured at Step 3.5,
  *before* archival mutates state.
- **Constraint B (sibling-archive resolution, not in the report)**: the script derives its
  archive input as `${STATE_PATH%state.json}archive/state.json`. A snapshot placed in a scratch
  directory therefore resolves to a non-existent sibling and yields `[]` — which is the desired
  behavior for `/todo` (only this run's tasks should be annotated), but it is load-bearing and
  must be stated in both the caller and the script's own header, not left to accident.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists and was consulted. No item on it corresponds to this work; the two
current phases cover documentation infrastructure and agent-system quality (extension linting,
frontmatter validation), neither of which this task advances. No roadmap items are claimed.

## Goals & Non-Goals

**Goals**:
- Make `roadmap-integration.sh` the single parser and structure-signal source for `/todo`,
  replacing `commands/todo.md`'s checkbox-only grep matcher.
- Wire `roadmap_structure.parseable` and the `warnings[]` codes into both `/todo` specs' dry-run
  and final output so an unparseable roadmap is always visible.
- Preserve `/todo`'s meta/expanded exclusion guarantee by filtering matches, never by modifying
  the shared script.
- Preserve `/todo`'s abandoned-task annotation, gated on the same parseable signal.
- Keep `commands/todo.md` and `skills/skill-todo/SKILL.md` describing the same design at their
  respective levels of detail, so the divergence this task closes does not reappear one level
  down.

**Non-Goals**:
- Adding `task_type` filtering or abandoned-status handling to `roadmap-integration.sh`. `/review`
  would never use either, and the script was recently fixed and verified; widening it is out of
  proportion to the defect.
- Extracting a third shared matching library (report option c).
- Resolving whether `skills/skill-todo/SKILL.md` is invoked by anything. The report notes
  `commands/todo.md` is a self-contained executor with no `Skill` tool in its `allowed-tools`;
  that dual-spec question is a standing drift risk for a separate task, and this task treats both
  files as live and authoritative.
- Updating `context/patterns/roadmap-update.md`. The report recommends it, but it is outside the
  declared `file_scope` for this task; it is recorded below as follow-up.
- Any edit under `.claude/`. That tree is a gitignored, disposable deploy artifact.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Annotate call placed after archival sees zero tasks (Constraint A) | H | H | Phase 3 mandates synthesizing the snapshot from the Step 3.5 eligible-task list, captured pre-archival; Phase 6 verifies the spec text states this explicitly |
| Scratch snapshot path written back over live `specs/state.json` | H | L | Snapshot is a `--state` input only, created under a scratch dir via `mktemp -d`, removed by `trap`; never a write target. Phase 3 states this as a rule |
| Only one of the two specs receives the fix, recreating the divergence | H | M | Phase 5 mirrors Phase 2-4 wording into `SKILL.md`; Phase 6 is a dedicated cross-file consistency sweep |
| Edits land in `.claude/` instead of `agent-system/extensions/core/` | H | M | Every phase names absolute source-store paths; Phase 6 verifies `git status` shows no `.claude/` modifications |
| Task-number citations leak into deliverables outside `specs/**` | M | M | Phase 6 greps all three edited files for task-number citation patterns |
| Double script invocation doubles roadmap parsing cost for `/todo` | L | H | Accepted: parsing is small next to archival directory moves and memory harvest, and strictly cheaper than a third bespoke parser |
| Report's inaccurate "table-based, zero checkboxes" premise is copied into spec prose | M | M | Overview records the correction; Phase 2 requires the spec to describe both checkbox and table-row matches as live |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6 | 1, 4, 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Document the script's caller contract [COMPLETED]

**Goal**: Make `roadmap-integration.sh`'s header state the two caller-contract facts a
parse-only/filtered-snapshot consumer depends on, so a future reader does not rediscover them by
debugging.

**Tasks**:
- [x] In the header comment block of
  `agent-system/extensions/core/scripts/roadmap-integration.sh`, add a short "Caller contract"
  subsection recording: (a) parse-only mode (no `--annotate`) is a supported, first-class call
  shape whose purpose is to obtain `roadmap_structure`/`warnings`/`roadmap_matches` without
  mutating the roadmap; (b) the archive input is resolved as the sibling
  `${STATE_PATH%state.json}archive/state.json`, so a caller passing a synthesized or filtered
  snapshot outside `specs/` gets an empty archive set, and that this is the supported way to scope
  a run to a caller-chosen task subset. *(completed)*
- [x] State explicitly that the script applies no `task_type` filter and has no abandoned-status
  branch, so a caller needing either must filter its own input or handle it itself. *(completed)*
- [x] Add no executable code. This phase is comment-only. *(completed: verified no non-comment
  hunk lines in diff)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/core/scripts/roadmap-integration.sh` - header comment block only

**Verification**:
- Diff read-through confirms every changed hunk lies inside the leading `#` comment block.
- `bash -n agent-system/extensions/core/scripts/roadmap-integration.sh` exits 0.
- `bash .claude/scripts/roadmap-integration.sh --roadmap specs/ROADMAP.md --state specs/state.json`
  still exits 0 and emits the `<!-- roadmap-structure ... -->` marker (behavior unchanged).

---

### Phase 2: Replace `/todo` Step 3.5 with a parse-only script call [COMPLETED]

**Goal**: `commands/todo.md`'s roadmap scan stops reimplementing matching and instead calls
`roadmap-integration.sh` parse-only, capturing the structure signal, while keeping the
meta/expanded eligibility partition.

**Tasks**:
- [x] Keep Step 3.5's existing "ensure `specs/ROADMAP.md` exists" preamble and Step 3.5.1's
  `roadmap_excluded_tasks[]` / `roadmap_eligible_tasks[]` partition unchanged — the partition is
  the meta/expanded exclusion guarantee and is still needed. *(completed)*
- [x] Replace Step 3.5.2 and Step 3.5.3 (the `todo_nonmeta_$$.jq` extraction and the
  grep-over-checkbox-lines matcher) with a parse-only invocation:
  `bash .claude/scripts/roadmap-integration.sh --roadmap specs/ROADMAP.md --state specs/state.json`
  (no `--annotate`), capturing the invocation's own exit status into a variable on the same line,
  mirroring `commands/review.md`'s Step 2.5 pattern. *(completed)*
- [x] Extract `roadmap_state`, `roadmap_matches`, `roadmap_structure`, and `warnings` from the
  payload, plus `annotation_summary.high_confidence_matches` and `.silent_noop`. *(completed)*
- [x] Reproduce `review.md`'s error-handling contract: script-missing and
  script-present-but-failed (non-zero exit or empty output) must both emit the same visible
  warning and fall back to the same fully-defined defaults, including
  `roadmap_structure='{"phases":0,"checkboxes":0,"table_rows":0,"parseable":false}'` so no
  downstream branch reads an unbound variable. *(completed)*
- [x] Add the eligibility filter: reduce `roadmap_matches[]` to those whose `matched_task` appears
  in `roadmap_eligible_tasks[]`, producing `roadmap_eligible_matches[]`. Everything downstream
  consumes the filtered array. State plainly that this is where meta-task exclusion is enforced,
  and that the shared script has no `task_type` filter of its own. *(completed)*
- [x] Update the "Track:" list and "Match Types" table at the end of Step 3.5 to describe the
  script's vocabulary (`confidence` high/medium/low; checkbox-sourced vs `source: "status_table"`
  matches carrying `line_index`/`raw_line`/`status_index`) instead of the removed
  `project_num:status:match_type:line_num:item_text` tuple format. Present both checkbox and
  table-row matching as live paths. *(completed)*

**Timing**: 1.25 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the edit is confined to Step 3.5 and its three
sub-steps in `commands/todo.md`. Confirm at implementation time by grepping the file for every
reference to `roadmap_matches`, `roadmap_completed_count`, `roadmap_abandoned_count`, and
`todo_nonmeta` before editing; any hit outside Step 3.5 belongs to Phase 3 or 4 and must be
recorded, not silently absorbed into this phase.

**Files to modify**:
- `agent-system/extensions/core/commands/todo.md` - Step 3.5 (scan/matching)

**Verification**:
- The parse-only command as written in the new Step 3.5 runs verbatim from the repo root, exits 0,
  and its output contains non-null `.roadmap_structure.parseable`, `.warnings`,
  `.roadmap_matches`, `.annotation_summary.high_confidence_matches`, and
  `.annotation_summary.silent_noop`.
- No `grep -n "^\s*- \[ \]"`-style roadmap matcher remains anywhere in Step 3.5.
- Step 3.5.1's eligibility partition is still present and unmodified.

---

### Phase 3: Rewrite `/todo` Step 5.5 annotation to reuse the script [COMPLETED]

**Goal**: `commands/todo.md` stops hand-writing roadmap line rewrites for completed tasks and
delegates them to `roadmap-integration.sh --annotate` against a filtered snapshot, while keeping
its own abandoned-task annotation gated on the parseable signal.

**Tasks**:
- [x] Replace Step 5.5's match-tuple parsing and its three Edit-based annotation recipes for
  *completed* tasks with: build a filtered state snapshot, then invoke
  `bash .claude/scripts/roadmap-integration.sh --roadmap specs/ROADMAP.md --state "$snapshot" --annotate`. *(completed)*
- [x] Specify snapshot construction precisely, and state why: create a scratch directory with
  `mktemp -d`, write the snapshot as `<scratchdir>/state.json`, and populate it as
  `{"active_projects": [ <the completed entries of roadmap_eligible_tasks[]> ]}` captured at
  Step 3.5 **before** Step 5 archival removed them from `active_projects`. Record that reading the
  live `specs/state.json` here would find none of the tasks being archived, because Step 5.5 runs
  after archival. *(completed)*
- [x] State the two snapshot safety rules as explicit prose: the snapshot is a `--state` **input
  only** and is never written back over `specs/state.json`; and because the script resolves its
  archive input as the sibling `<scratchdir>/archive/state.json`, which does not exist, previously
  archived tasks are deliberately excluded from this run's annotation. Remove the scratch
  directory via `trap`. *(completed)*
- [x] Note that `/todo` therefore never implements checkbox or table-row rewriting itself — it
  constructs an input and reads a payload. *(completed)*
- [x] Keep the abandoned-task annotation branch (`- [ ] {item} *(Task {N} abandoned: {reason})*`,
  checkbox stays unchecked) as `/todo`-owned logic, and state that the shared script has no
  abandoned-status code path at all. Gate the branch on `roadmap_structure.parseable`: when
  `parseable` is false, do not attempt the annotation and emit the unparseable warning instead of
  silently no-op'ing. *(completed)*
- [x] Update Step 5.5's tracking block to record `annotations_made`, `items_skipped`,
  `skipped_reasons`, `high_confidence_matches`, and `silent_noop` from the annotate payload,
  alongside `/todo`'s own `roadmap_abandoned_annotated` count. Retire the `by_match_type`
  `explicit`/`exact`/`summary` breakdown, which described the removed matcher. *(completed)*
- [x] Keep the existing Safety Rules bullet list, revised to name which rules the script now
  enforces (already-annotated skip, one-line-for-one-line replacement, stale-line guard via
  `line_index`/`raw_line`) versus which remain `/todo`'s own for the abandoned path. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the completed-task annotation recipes live only in Step
5.5 of `commands/todo.md`. Confirm by grepping the file for `*(Completed:` and
`*(Task ` before editing; hits in the Notes section belong to Phase 4.

**Files to modify**:
- `agent-system/extensions/core/commands/todo.md` - Step 5.5 (annotation application)

**Verification**:
- Build a throwaway snapshot in a scratch dir exactly as the new prose specifies, from two
  synthetic completed entries, and run the documented `--annotate` command against a **copy** of
  `specs/ROADMAP.md` in the same scratch dir; confirm it exits 0 and returns a well-formed
  `annotation_summary`. The real `specs/ROADMAP.md` and `specs/state.json` must be untouched
  (`git status --short specs/` shows no change to either).
- The phrase describing the pre-archival capture of eligible tasks is present and unambiguous.
- The abandoned branch is present and explicitly gated on `parseable`.

---

### Phase 4: Wire the acceptance criterion into `/todo`'s output surfaces [COMPLETED]

**Goal**: Eliminate the silent-omission behavior in `commands/todo.md` — an unparseable roadmap
must always produce a visible warning in both dry-run and final output — and bring the Notes
section in line with the new design.

**Tasks**:
- [x] In the Step 4 dry-run output section, replace "If no roadmap matches were found (from Step
  3.5), omit the 'Roadmap updates' section" with a three-way branch: `parseable == true` and zero
  eligible matches -> omit the section as before (legitimately nothing to do); `parseable ==
  false` -> **always** print the warning line
  `Warning: roadmap structure unrecognized (0 phases, 0 checkboxes, 0 table rows) -- see roadmap_structure in the payload`,
  matching `commands/review.md`'s wording; `silent_noop == true` -> print the
  `Warning: roadmap annotation no-op (...)` line naming `high_confidence_matches` and pointing at
  `skipped_reasons`. *(completed)*
- [x] Apply the identical three-way branch to the final Output section's roadmap rule and to the
  "Section Inclusion Rules" table row for Roadmap, replacing "If no roadmap items were updated ...
  omit the 'Roadmap updated' section". *(completed)*
- [x] Add a one-line statement of the invariant at both sites: omission is permitted only when the
  roadmap parsed successfully; an unparseable roadmap is never reportable as a successful
  annotation pass. *(completed)*
- [x] Rewrite the Notes section's "Roadmap Updates -> Matching Strategy" subsection: matching is
  performed by `roadmap-integration.sh` (parse-only for the scan, `--annotate` against a filtered
  snapshot for application); `roadmap_items` remains the highest-confidence producer input;
  `(Task N)` references remain a recognized high-confidence signal; drop the "Summary-based search
  (Future enhancement)" placeholder, which described a matcher that no longer exists here.
  *(completed)*
- [x] Preserve the Producer/Consumer Workflow, Annotation Formats, Date Format, Abandoned Reason,
  and Well-Formed Completion Summaries subsections, adjusting only statements that contradict the
  new mechanism. *(completed)*

**Timing**: 1 hour

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly three output surfaces exist in
`commands/todo.md` (Step 4 dry-run, final Output section, Section Inclusion Rules table) plus the
Notes subsection. Confirm by grepping for `omit the` and `Roadmap` across the whole file before
editing; every hit must be either addressed here or explicitly recorded as out of scope.

**Files to modify**:
- `agent-system/extensions/core/commands/todo.md` - Step 4 dry-run, Output section, Section
  Inclusion Rules table, Notes/Roadmap Updates

**Verification**:
- `grep -n "omit the .Roadmap" agent-system/extensions/core/commands/todo.md` returns only
  occurrences that are explicitly conditioned on `parseable == true`.
- Both warning strings appear in the file and match `commands/review.md`'s wording.
- No remaining reference to the removed `explicit`/`exact`/`summary` tuple vocabulary.

---

### Phase 5: Mirror the design into skill-todo/SKILL.md [COMPLETED]

**Goal**: `skills/skill-todo/SKILL.md` describes the same parser, the same eligibility filter, the
same annotate mechanism, and the same output gate, at its own (prose, stage-based) level of
detail.

**Tasks**:
- [x] Stage 5 (`ScanRoadmap`): keep the ROADMAP.md-existence preamble and the meta/expanded
  exclusion wording. Replace steps 3-4 ("Match against ROADMAP.md items" / "Track roadmap_matches
  array with confidence levels") with: invoke `roadmap-integration.sh` parse-only; capture
  `roadmap_structure`, `warnings`, and `roadmap_matches`; filter matches to roadmap-eligible tasks
  before treating any as an annotation candidate. State that this stage performs no matching of
  its own. *(completed)*
- [x] Stage 5: record the same error-handling contract in one sentence — script missing, non-zero
  exit, or empty output all produce a visible warning and the `parseable: false` fallback, never
  silence. *(completed)*
- [x] Stage 11 (`UpdateRoadmap`): replace the two-line annotation recipe with the split design —
  completed matches are applied by invoking the script with `--annotate` against a filtered
  snapshot synthesized from the Stage 5 eligible-task capture (taken before Stage 10 archival);
  abandoned matches are annotated by the skill itself, since the script has no abandoned path,
  gated on `parseable`. Keep the `- [ ] item *(Task {N} abandoned: reason)*` format. *(completed)*
- [x] Stage 11: carry the snapshot safety rules — input-only, scratch directory, `trap` cleanup,
  no sibling archive lookup so only this run's tasks are annotated. *(completed)*
- [x] Stage 8 (`DryRunOutput`): change the bare `Roadmap updates needed` bullet to specify the
  same three-way branch as `commands/todo.md`'s dry-run — omit only when `parseable` is true and
  there are no eligible matches; always print the unparseable warning otherwise; print the
  annotation-no-op warning when `silent_noop` is true. *(completed)*
- [x] Stage 16 (`OutputResults`): apply the same branch to the `Updates applied (roadmap
  annotations/...)` line, with the same never-silent invariant stated once. *(completed)*

**Timing**: 1.25 hours

**Depends on**: 4

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly four stages carry roadmap responsibilities in
`SKILL.md` (5, 8, 11, 16). Confirm by grepping the file for `roadmap|Roadmap|ROADMAP` before
editing and reconciling every hit against that set; hits in Stage 10's control-flow pointers and
Stage 15's commit-message counts are cross-references, not annotation logic, and should be left
alone unless they contradict the new design.

**Files to modify**:
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` - Stages 5, 8, 11, 16

**Verification**:
- Each of Stages 5, 8, 11, 16 names `roadmap-integration.sh`, `roadmap_structure.parseable`, or
  both, as appropriate to its role.
- The abandoned-annotation format is unchanged from the current file.
- The XML stage structure is intact: `<stage>`/`<action>`/`<process>` nesting still balances, and
  the stage id list is unchanged.

---

### Phase 6: Consistency sweep and acceptance verification [NOT STARTED]

**Goal**: Prove the binding acceptance criterion holds, prove the two specs agree, and prove the
source-store and no-task-reference rules were honored.

**Tasks**:
- [ ] **Acceptance test**: in a scratch directory, create a `ROADMAP.md` fixture containing no
  `## Phase` headings, no checkboxes, and no pipe-delimited status table, plus a minimal
  `state.json`. Run the parse-only command exactly as `commands/todo.md` Step 3.5 now specifies.
  Confirm the payload reports `roadmap_structure.parseable == false` and
  `warnings` contains `unparseable_roadmap`, and that the stderr banner appears. Then read both
  specs' output sections and confirm each one, on that input, mandates a printed warning rather
  than an omitted section. Record the observed values.
- [ ] **Non-regression test**: run the same parse-only command against the real
  `specs/ROADMAP.md`; confirm `parseable == true` with non-zero `checkboxes`, and that both specs
  permit omission only on this branch.
- [ ] **Cross-spec consistency**: diff the two specs' descriptions of the parser call, the
  eligibility filter, the snapshot construction, the abandoned-path ownership, and the output
  gate. Any disagreement is a defect to fix here, not to leave for a reader to reconcile.
- [ ] **Source-store check**: `git status --short` shows modifications only under
  `agent-system/extensions/core/` and `specs/`; zero modified paths under `.claude/`.
- [ ] **No-task-references check**: grep all three edited files for task-number citation patterns
  (`task [0-9]`, `tasks [0-9]`, `(Task [0-9]`) and confirm every surviving hit is a literal
  annotation-format template (for example `*(Completed: Task {N}, {DATE})*`) rather than a
  citation of this repository's task numbers.
- [ ] **Structural checks**: `bash -n` on the script; confirm no `.claude/` path was edited; confirm
  both markdown specs still parse as well-formed documents (headings and code fences balanced).

**Timing**: 0.75 hours

**Depends on**: 1, 4, 5

**Verification Tier**: full

**Files to modify**:
- None expected. Any file touched here is a defect fix surfaced by the sweep and must be reported
  as such in the summary.

**Verification**:
- The unparseable fixture produces `parseable: false` + `unparseable_roadmap`, and both specs
  mandate a visible warning for that case — the binding acceptance criterion, demonstrated rather
  than asserted.
- The real roadmap still parses (`parseable: true`, `checkboxes > 0`).
- `git status --short` shows no `.claude/` modifications.

---

## Testing & Validation

- [ ] Parse-only invocation from `commands/todo.md` Step 3.5 runs verbatim, exits 0, and yields
  every field the spec goes on to read.
- [ ] Filtered-snapshot `--annotate` invocation from Step 5.5 runs against a scratch roadmap copy
  and returns a well-formed `annotation_summary`, leaving `specs/ROADMAP.md` and
  `specs/state.json` unmodified.
- [ ] Zero-phase/zero-checkbox/zero-table-row roadmap yields `parseable: false` and
  `warnings: ["unparseable_roadmap"]`, and both specs mandate a printed warning on that branch.
- [ ] Real `specs/ROADMAP.md` still yields `parseable: true` with non-zero checkbox count
  (non-regression against the report's inaccurate table-only premise).
- [ ] `bash -n agent-system/extensions/core/scripts/roadmap-integration.sh` exits 0.
- [ ] Both specs retain the meta/expanded exclusion partition and the abandoned annotation format.
- [ ] No modified files under `.claude/`; no task-number citations in the three edited files.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/roadmap-integration.sh` (header caller contract; no code
  change)
- `agent-system/extensions/core/commands/todo.md` (Step 3.5, Step 5.5, Step 4 dry-run, Output
  section, Section Inclusion Rules, Notes/Roadmap Updates)
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` (Stages 5, 8, 11, 16)
- `specs/914_converge_todo_roadmap_annotation_with_script/summaries/01_converge-todo-roadmap-annotation-summary.md`

**Follow-up recorded, not performed here**: `context/patterns/roadmap-update.md` documents the
now-superseded checkbox-only matching strategy and never mentions `roadmap-integration.sh`. It is
outside this task's declared `file_scope`; a separate task should repoint it at the parse-only +
filtered-annotate pattern.

## Rollback/Contingency

All changes are confined to three markdown/shell files in the source store, with no schema or
state migration. To revert: `git revert` the phase commits, in reverse order, or
`git checkout <pre-task-sha> -- agent-system/extensions/core/commands/todo.md
agent-system/extensions/core/skills/skill-todo/SKILL.md
agent-system/extensions/core/scripts/roadmap-integration.sh`. The `.claude/` deploy tree is
regenerated from the source store and needs no separate rollback. Because each phase commits
independently, a partial rollback to any completed-phase boundary is safe: Phases 1-2 leave
`/todo` with a parse-only call and an unchanged annotation path, which is degraded but not broken,
and Phase 3 is the first phase whose partial application would leave the completed-task annotation
path in an inconsistent state — so if work stops mid-task, stop at a phase boundary, never inside
Phase 3.
