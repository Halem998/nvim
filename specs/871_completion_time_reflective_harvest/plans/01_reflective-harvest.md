# Implementation Plan: Task #871

- **Task**: 871 - Completion-time reflective harvest (/todo + /learn)
- **Status**: [COMPLETED]
- **Effort**: 4.5 hours
- **Dependencies**: Task 869 (event store, COMPLETE), Task 870 (hook event logging, COMPLETE)
- **Research Inputs**: specs/871_completion_time_reflective_harvest/reports/01_completion_time_reflective_harvest.md
- **Artifacts**: plans/01_reflective-harvest.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a structured completion-time reflection (`what_worked` / `what_was_hard` / `what_was_missed`
/ `successes`) that rides alongside the existing `memory_candidates` / `completion_summary`
pipeline. The reflection is emitted by an implementation agent on `.return-meta.json`, persisted
as a new top-level `reflection` object on the task's `state.json` entry at the
`orchestrator-postflight.sh` completion seam, logged once to the unified event store
(`specs/events.jsonl`) as an already-documented `reflection` event, surfaced read-only through
`skill-todo`'s existing AskUserQuestion harvest prompt, and pulled in as an additional reviewable
segment by `/learn --task N`. All edits are authored in the `agent-system/extensions/` source
tree only; deployed `.claude/` / `.opencode/` copies are not synced by this task (following the
task 870 precedent).

### Research Integration

The research report resolves the two scope questions this plan must decide and provides
line-level seam locations, all verified against the live source tree:

- **Event schema (no change needed)**: `events-format.md` already documents `event_type:
  "reflection"` with `detail = {what_worked, what_was_hard, what_was_missed, successes}` and
  `category: "success"`. `events-append.sh`, `events-schema.json`, and `events-format.md` need no
  edits — only one new call site in `orchestrator-postflight.sh`.
- **Postflight seams (verified line ranges)**: Stage 6 metadata reads (lines 143-158), Stage 6b
  event emission (lines 172-202), Stage 7b implement-only `completion_summary`/`roadmap_items`
  write (lines 245-285), Stage 7c `memory_candidates` propagation (lines 287-306).
- **Placement decision**: `reflection` is a top-level field on `.return-meta.json` and on the
  `state.json` task entry — exact parity with `memory_candidates`, matching the task's "alongside
  memory_candidates" phrasing (not nested under `completion_data`).
- **skill-todo seams**: Stage 7 (`HarvestMemories`), Stage 8 (`DryRunOutput`), Stage 9
  (`InteractivePrompts`), Stage 14 (`CreateMemories`) cleanup note.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation was requested (roadmap_flag not set). No roadmap phases added.

### Scope Decisions (resolved per delegation instructions)

Two files flagged in the report as outside the declared `file_scope` are resolved here:

1. **`agent-system/extensions/memory/skills/skill-memory/SKILL.md` — SCOPE EXPANDED (functional
   edit).** This file holds the real `/learn --task N` artifact-scan logic (Task Mode Execution,
   Step 2 "Scan Artifacts"). The task's stated goal explicitly promises `/learn --task` will
   *extend* to surface reflections, not merely document them. `learn.md` is a thin delegation
   layer that cannot make the behavior real on its own. Per `state-management.md`, `file_scope`
   is "descriptive/anticipated (not filesystem-validated)", so expanding it by this one
   well-understood file is sanctioned. Handled in Phase 4.

2. **`agent-system/extensions/core/context/reference/state-management-schema.md` — SCOPE EXPANDED
   (natural-consequence doc sync).** This file documents the `state.json` task-entry schema
   including `completion_summary` / `roadmap_items` / `memory_candidates`. Adding a `reflection`
   field to those entries without documenting it here leaves the schema doc silently inaccurate.
   A single field-table row plus one short paragraph keeps the deliverable internally consistent
   (preferred per the delegation instruction). Handled in Phase 1.

For the two confirmed-dormant/legacy files, functional reimplementation is deliberately avoided
(minimal doc-only touches only): `memory-harvest.sh` (dead code, no caller) receives a header
comment; `commands/todo.md` (pre-existing drift, no memory-harvest stages) receives a single
Notes pointer. Both handled in Phase 5.

## Goals & Non-Goals

**Goals**:
- Persist `reflection` as a new top-level object field on the `state.json` task entry, written at
  the `orchestrator-postflight.sh` completion seam (implement-only, `status == implemented`-gated,
  overwrite semantics).
- Emit exactly one `reflection` event to `specs/events.jsonl` per implement postflight when a
  reflection is present, using the already-documented `event_type`/`category`/`detail` shape.
- Document `reflection` as an optional top-level field in `return-metadata-file.md` and in
  `state-management-schema.md`, mirroring the existing `memory_candidates` documentation.
- Collect and surface reflections read-only through `skill-todo`'s existing Stage 9
  AskUserQuestion harvest prompt (augmented description text, no new selectable options), with a
  Stage 8 dry-run summary line and a Stage 14 cleanup note.
- Extend `/learn --task N` (functionally, via `skill-memory/SKILL.md` Step 2) to include a
  present `reflection` field as an additional reviewable segment, and document it in `learn.md`.
- Keep `memory/EXTENSION.md` / `core/EXTENSION.md` / `core/manifest.json` consistent.

**Non-Goals**:
- No changes to `events-schema.json`, `events-format.md`, or `events-append.sh` — the schema
  already accommodates the reflection payload.
- No new prompt or new selectable options in `skill-todo` Stage 9 — reflection is surfaced as
  read-only context only.
- No overwrite/append change to `memory_candidates` or `completion_summary` handling — reflection
  rides alongside, it does not replace.
- No full re-sync of the pre-existing `commands/todo.md` <-> `skill-todo/SKILL.md` memory-harvest
  drift (out of scope, pre-existing).
- No functional code added to the dormant `memory-harvest.sh` (no caller exists).
- No deployment/sync to `.claude/` or `.opencode/` copies (source-tree edits only; expected
  `check-extension-docs.sh` doc-lint drift is an accepted, documented finding per task 870).
- No new script or skill file is introduced, so `core/manifest.json` is verify-only.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Free-text reflection fields (4, multi-sentence) break the existing python3 triple-quote string-interpolation write pattern on embedded quotes/newlines | H | M | For the reflection write specifically, read the object directly from the metadata file via `jq --argjson` / a temp file rather than bash-variable + `'''${...}'''` interpolation. Leave existing fields untouched. |
| `/learn --task` support is documented but not functional if `skill-memory/SKILL.md` is left untouched | M | Low (scope expanded) | Phase 4 edits `skill-memory/SKILL.md` Step 2 to read `reflection` from state.json and present it as a pseudo-artifact segment. |
| Editing `commands/todo.md` is misread as "fixing" the larger pre-existing memory-harvest drift, causing scope creep | M | M | Bound the `todo.md` change to a single Notes pointer; explicitly state in Non-Goals that full re-sync is out of scope. |
| Deployed `.claude/`/`.opencode/` copies drift and `check-extension-docs.sh` reports it | L | H | Accept and document as expected (task 870 precedent); do not sync. |
| A deliverable file outside `specs/**` cites a task number, violating no-task-references rule | M | M | Every `agent-system/` edit uses durable anchors (field names, doc/section titles), never "task 871". Verified in Phase 6. |
| `reflection` written for non-completion lifecycle stages (research/plan) | M | Low | Gate the state.json write on `operation_type == "implement" && status == "implemented"`, matching `completion_summary` gating. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5 | 2, 3, 4 |
| 4 | 6 | 5 |

Phases within the same wave can execute in parallel (no file overlap across phases).

### Phase 1: Define the reflection data contract [COMPLETED]

**Goal**: Establish the `reflection` field shape once, so producer/consumer phases edit against a
fixed contract.

**Tasks**:
- [x] In `agent-system/extensions/core/context/formats/return-metadata-file.md`, add a
  `### reflection (optional)` section as a top-level sibling to `### memory_candidates
  (optional)`. Document: Type = object; Include-if = "status is `implemented` and the agent
  captured a completion-time reflection (optional even then)"; a 4-field table (`what_worked`,
  `what_was_hard`, `what_was_missed`, `successes` — all strings, ~1-3 sentences each,
  all-or-nothing per agent judgment); a note that skill postflight propagates it to the
  `state.json` task entry with overwrite (not append) semantics. *(completed)*
- [x] Add a worked `reflection` object to the existing "Implementation Success (Non-Meta)" JSON
  example so the shape is concrete. *(completed)*
- [x] In `agent-system/extensions/core/context/reference/state-management-schema.md`, add a
  `reflection` row/paragraph to the task-entry field documentation, immediately following the
  existing `memory_candidates` entry, matching its documentation structure. *(completed)*

**Timing**: 45 min

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/context/formats/return-metadata-file.md` - new `reflection`
  section + example
- `agent-system/extensions/core/context/reference/state-management-schema.md` - new `reflection`
  field row (scope-expansion, natural-consequence sync)

**Verification**:
- Both files describe `reflection` as a top-level object with the four named string sub-fields.
- No task-number citations introduced (durable anchors only).

---

### Phase 2: Persist reflection at the postflight completion seam [COMPLETED]

**Goal**: Read, event-log, and persist the `reflection` field in `orchestrator-postflight.sh`.

**Tasks**:
- [x] Stage 6 (near line 143-158): initialize `reflection="null"` with the other metadata
  defaults and add `reflection=$(jq -c '.reflection // null' "$metadata_file")` inside the
  metadata-read block. *(completed)*
- [x] Stage 6b (after the existing `orchestrator_status` event append, ~line 202): add a second,
  independent `events-append.sh` call guarded on `[ "$reflection" != "null" ] && [ -n
  "$reflection" ]`, with `--event-type reflection --category success --checkpoint postflight
  --task "$task_number" --session "$session_id" --detail-json "$reflection"` and a descriptive
  `--message`. Non-blocking (`|| echo "[postflight] WARNING: reflection event append failed
  (non-blocking)" >&2`). Do NOT reuse the `orchestrator_status` event line. *(completed)*
- [x] Add a new "Stage 7d" block after Stage 7c (~line 306) that writes `reflection` as a
  top-level object on the matched `active_projects[]` entry. Gate on `operation_type ==
  "implement" && status == "implemented" && reflection != "null"`. Use **overwrite** semantics
  (`p['reflection'] = new_reflection`), not append. *(completed: used jq
  `(.active_projects[] | select(.project_number == $num)).reflection = $refl` rather than a
  python3 dict assignment, matching the Stage 8 jq style already in the file)*
- [x] For this write, read the object safely: prefer `jq --argjson`/temp-file or `json.loads`
  reading the value out of the metadata file directly, rather than extending the fragile
  `'''${...}'''` bash-interpolation pattern to four free-text fields (see Risks). *(completed:
  jq --argjson)*
- [x] Update the file's header stage-comment block (lines 24-36) to mention the new reflection
  read/event/write so the documented stage map stays accurate. *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` - Stage 6 read, Stage 6b
  event, new Stage 7d state.json write, header comment

**Verification**:
- `bash -n orchestrator-postflight.sh` passes (syntax).
- Manual trace: with a `.return-meta.json` containing a `reflection` object and
  `status=implemented`, the Stage 7d block would write the object to state.json; with no
  `reflection` (null), no event and no write occur.
- Non-implement operations (research/plan) never write `reflection`.

---

### Phase 3: Surface reflections in skill-todo harvest [COMPLETED]

**Goal**: Collect per-task reflections during archival and present them read-only through the
existing AskUserQuestion prompt.

**Tasks**:
- [x] Stage 7 (`HarvestMemories`): add a parallel collection sub-step reading `reflection //
  null` per archived task in the same loop as `memory_candidates`, storing a `harvest_reflections`
  list of `{task_number, what_worked, what_was_hard, what_was_missed, successes}`; skip tasks with
  no reflection. No dedup/tiering (reflections are one-per-task, not vault-deduped). *(completed)*
- [x] Stage 8 (`DryRunOutput`): add one summary line `Reflections: {N} task(s) reported a
  completion-time reflection`, shown only when `harvest_reflections` is non-empty (mirrors the
  existing memory-candidate dry-run line). *(completed)*
- [x] Stage 9 (`InteractivePrompts`): augment the existing memory-harvest AskUserQuestion's
  `description`/header text with a per-task read-only reflection block when `harvest_reflections`
  is non-empty. Do NOT add new selectable options or a second prompt; the multiSelect mechanics
  (tiers, dedup, NOOP) are unchanged. Omit the section entirely when empty. *(completed)*
- [x] Stage 14 (`CreateMemories`): extend the existing cleanup note to state that `reflection` is
  cleaned identically to `memory_candidates` when the task entry is moved to archive (no separate
  cleanup logic — it rides the archive-move). *(completed)*

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` - Stage 7 collection, Stage 8
  dry-run line, Stage 9 prompt description, Stage 14 cleanup note

**Verification**:
- Stage 9 change is additive (no new options); reads correctly when `harvest_reflections` is
  empty (section omitted) and non-empty (read-only block shown).
- No task-number citations introduced.

---

### Phase 4: Extend /learn --task to include reflection [COMPLETED]

**Goal**: Make `/learn --task N` functionally surface a present `reflection` field as an
additional reviewable segment, and document it.

**Tasks**:
- [x] `agent-system/extensions/memory/skills/skill-memory/SKILL.md`, Task Mode Execution, Step 2
  "Scan Artifacts": after the existing `find "$task_dir" -type f -name "*.md"` scan, add a read
  of the task's `reflection` field from `specs/state.json` (jq selector on
  `active_projects[] | select(.project_number == N) | .reflection // null`); when present,
  present it as an additional pseudo-artifact/segment alongside the markdown artifacts. Keep the
  change small (~15 lines) and consistent with the existing segment-presentation pattern.
  *(completed: also touched Step 3's option list and Step 4's content-read note for the
  pseudo-artifact to be functionally selectable/processable, not just read)*
- [x] `agent-system/extensions/memory/commands/learn.md`, Task Mode "Scan Artifacts" workflow
  step: document that when the task's `state.json` entry has a `reflection` field, it is included
  as an additional reviewable segment alongside the markdown artifacts. *(completed)*

**Timing**: 45 min

**Depends on**: 1

**Files to modify**:
- `agent-system/extensions/memory/skills/skill-memory/SKILL.md` - Step 2 functional reflection
  read (scope-expansion)
- `agent-system/extensions/memory/commands/learn.md` - Task Mode doc note

**Verification**:
- `skill-memory/SKILL.md` Step 2 reads `reflection` from state.json and would present it when
  present; behavior unchanged when absent (`// null`).
- `learn.md` documentation matches the implemented behavior.
- No task-number citations introduced.

---

### Phase 5: Minimal legacy touches and extension consistency [COMPLETED]

**Goal**: Apply the bounded doc-only touches to dormant/legacy files and keep the extension
manifest/EXTENSION docs consistent — after the functional phases have settled so cross-references
are accurate.

**Tasks**:
- [x] `agent-system/extensions/core/scripts/memory-harvest.sh`: add a one-line header comment
  noting the script is presently uncalled and that `reflection` lives on the same task entries but
  is consumed via `skill-todo`'s inline harvest logic, not this script. No functional change.
  *(completed)*
- [x] `agent-system/extensions/core/commands/todo.md`: add a single small Notes pointer that
  completion-time reflections (when present) are surfaced during archival per
  `skill-todo/SKILL.md`'s harvest stage. Do not re-sync the broader memory-harvest workflow.
  *(completed)*
- [x] `agent-system/extensions/memory/EXTENSION.md`: add a short note (under Memory Lifecycle or a
  small subsection) that `/todo`'s harvest also surfaces completion-time reflections (state.json
  `reflection` field) alongside `memory_candidates`, and `/learn --task N` can pull them in as an
  additional segment. *(completed)*
- [x] `agent-system/extensions/core/EXTENSION.md`: verify the existing "Unified Event Store"
  bullet (which already references reflections) still reads correctly; adjust wording only if
  needed for consistency. *(completed: verified, already reads correctly, no edit made)*
- [x] `agent-system/extensions/core/manifest.json`: verify no new script/skill file was
  introduced (none is) and therefore no `provides` entry is required. Verify-only, expected no-op.
  *(completed: `jq empty` passes, no edit made)*

**Timing**: 45 min

**Depends on**: 2, 3, 4

**Files to modify**:
- `agent-system/extensions/core/scripts/memory-harvest.sh` - header comment (doc-only)
- `agent-system/extensions/core/commands/todo.md` - Notes pointer
- `agent-system/extensions/memory/EXTENSION.md` - lifecycle note
- `agent-system/extensions/core/EXTENSION.md` - consistency check (likely no edit)
- `agent-system/extensions/core/manifest.json` - verify-only (likely no edit)

**Verification**:
- `memory-harvest.sh` still parses (`bash -n`); no behavioral change.
- `manifest.json` remains valid JSON (`jq empty`).
- No task-number citations introduced.

---

### Phase 6: End-to-end verification [COMPLETED]

**Goal**: Confirm consistency across all edited files and enforce project rules.

**Tasks**:
- [x] `bash -n` on `orchestrator-postflight.sh` and `memory-harvest.sh`. *(completed: both pass)*
- [x] `jq empty` on `core/manifest.json`. *(completed: passes)*
- [x] Grep all edited files outside `specs/**` for task-number citation patterns (e.g. "task
  871", "task 8", "tasks ") and confirm none were introduced — every provenance reference uses a
  durable anchor. *(completed: zero citations introduced by this task's edits; five pre-existing
  "task 822" citations found in skill-memory/SKILL.md predate this task and are outside its diff,
  confirmed via git diff against the pre-implementation commit)*
- [x] Cross-check field-name consistency: `what_worked` / `what_was_hard` / `what_was_missed` /
  `successes` spelled identically across `return-metadata-file.md`, `state-management-schema.md`,
  `orchestrator-postflight.sh`, `skill-todo/SKILL.md`, `skill-memory/SKILL.md`, and matching the
  `detail` shape documented in `events-format.md`. *(completed: all four field names spelled
  identically everywhere they appear; orchestrator-postflight.sh treats reflection as an opaque
  jq object and does not name individual fields, which is correct/expected — it never needs to)*
- [x] Confirm `events-schema.json` / `events-format.md` / `events-append.sh` were NOT modified.
  *(completed: `git diff` against the pre-implementation commit for all three files is empty)*
- [x] Note (do not fix) the expected `.claude/`/`.opencode/` deployment drift as an accepted
  finding per the precedent set by the prior sibling task in this same effort. *(completed: noted,
  not fixed — no `.claude/` or `.opencode/` files were touched by this task)*

**Timing**: 30 min

**Depends on**: 5

**Files to modify**: none (verification only)

**Verification**:
- All syntax/JSON checks pass.
- Field names consistent across every file.
- Zero task-number citations in `agent-system/` edits.

## Testing & Validation

- [x] `bash -n agent-system/extensions/core/scripts/orchestrator-postflight.sh` passes.
- [x] `bash -n agent-system/extensions/core/scripts/memory-harvest.sh` passes.
- [x] `jq empty agent-system/extensions/core/manifest.json` passes.
- [x] The four reflection sub-field names are spelled identically across all producing/consuming
  files and match `events-format.md`'s documented `detail` shape.
- [x] Manual trace of `orchestrator-postflight.sh`: reflection present + `status=implemented` ->
  one `reflection` event + state.json write; reflection absent -> neither. (traced by reading the
  Stage 6/6b/7d guards: all three gate on `[ "$reflection" != "null" ]`, and Stage 7d additionally
  gates on `operation_type == "implement" && status == "implemented"`)
- [x] `skill-todo` Stage 9 prompt is additive (no new selectable options); empty
  `harvest_reflections` omits the reflection section cleanly.
- [x] No task-number citations in any file outside `specs/**`.
- [x] `events-schema.json`, `events-format.md`, `events-append.sh` unchanged.

## Artifacts & Outputs

- `agent-system/extensions/core/context/formats/return-metadata-file.md` (reflection section)
- `agent-system/extensions/core/context/reference/state-management-schema.md` (reflection field)
- `agent-system/extensions/core/scripts/orchestrator-postflight.sh` (read/event/write seams)
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` (harvest/surface/cleanup)
- `agent-system/extensions/memory/skills/skill-memory/SKILL.md` (/learn --task scan)
- `agent-system/extensions/memory/commands/learn.md` (doc note)
- `agent-system/extensions/core/scripts/memory-harvest.sh` (header comment)
- `agent-system/extensions/core/commands/todo.md` (Notes pointer)
- `agent-system/extensions/memory/EXTENSION.md` (lifecycle note)
- `agent-system/extensions/core/EXTENSION.md` (consistency check)
- `agent-system/extensions/core/manifest.json` (verify-only)
- `specs/871_completion_time_reflective_harvest/summaries/01_reflective-harvest-summary.md`
  (implementation summary)

## Rollback/Contingency

- All edits are additive and confined to the `agent-system/extensions/` source tree. Revert via
  `git checkout -- <file>` per file; no data migrations or destructive operations are involved.
- The postflight write is guarded and non-blocking: if the Stage 7d write or the reflection event
  append fails, existing `completion_summary` / `memory_candidates` handling is unaffected.
- If the `skill-memory/SKILL.md` scope expansion (Phase 4) proves larger than estimated, fall
  back to documentation-only in `learn.md` and record a flagged follow-up, keeping the rest of the
  plan intact.
```
