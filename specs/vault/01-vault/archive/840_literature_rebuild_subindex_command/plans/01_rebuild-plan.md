# Implementation Plan: Task #840

- **Task**: 840 - Add `--rebuild` flag to `/literature` for per-repo sub-index conformance
- **Status**: [COMPLETED]
- **Effort**: 7 hours
- **Dependencies**: #841 (complete — extension source now matches deployed scripts; drift guard installed)
- **Research Inputs**: specs/840_literature_rebuild_subindex_command/reports/01_rebuild-research.md
- **Artifacts**: plans/01_rebuild-plan.md (this file)
- **Standards**:
  - .claude/context/formats/plan-format.md
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/context/workflows/task-breakdown.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add a `/literature --rebuild` flag that brings a repo's per-repo sub-index (`specs/literature-index.json`) into conformance with the global Literature corpus and current conventions. The interface is settled: `--rebuild` sits beside `--validate` in the mode-detection table (NOT a top-level `/rebuild`). All work lands in the **extension source only** (`.claude/extensions/literature/`), which task #841 reconciled against the deploy tree; a drift guard now catches divergence.

The command dispatches to a new `handle_rebuild()` case in `skill-literature/SKILL.md`. `handle_rebuild()` first detects an absent sub-index and defers to the existing `literature-create-setup-task.sh` path (never duplicating or erroring), then presents an `AskUserQuestion` multiSelect job-picker for four jobs. Jobs 1, 2, 4 are read-only and idempotent; Job 3 is the only writer and only after an explicit confirm-after-diff gate. `--dry-run` is supported for all jobs (it only meaningfully changes Job 3, since 1/2/4 never write).

### Research Integration

The plan is built directly on `reports/01_rebuild-research.md`, which corrects three original task assumptions:

- **Insertion point confirmed**: `literature.md` step-1 mode-detection table (priority-0, before `--validate`) plus a new `<step_X>` delegating `mode=rebuild`; SKILL.md step-4 `case "$mode" in` gets `rebuild) handle_rebuild ;;`.
- **Job 1 largely already written as dead code**: SKILL.md's "Sub-Index Management > Validate" block (~lines 1719-1753) is an unwired dangling-ref lint referencing a non-existent `--subindex` flag. The plan **wires up / reuses** it rather than rewriting.
- **Job 2 schema-check correction (single most important constraint)**: the nominal `{doc_id, relevance, source}` shape does NOT match live data. cslib omits `source`; BimodalLogic uses `reason` (not `relevance`) plus load-bearing extra fields (`hazard`, `citation_rule`, `known_corrections`, `audits`) documenting a real citation-fidelity issue on `rabinovich_2014`. Job 2 checks **structural minimums only** and MUST NOT enforce one rigid shape or strip/flag legitimate extra curation fields.
- **Job 4 premise confirmed live**: 25/97 `sources/<dir>/` directories have zero rows in `.literature.db`'s `chunks_data`. Root cause: `--convert` never invokes the chunker/indexer (only `--ingest` does). `document_metadata` is empty (0 rows). Job 4 asserts per-directory and reports the gap; remediation of the convert-vs-ingest pipeline gap is out of scope (see Non-Goals).
- **Re-measured baseline**: global index 282 entries; nvim sub-index ABSENT; BimodalLogic 2 entries / 0 dangling; cslib 11 / 0 dangling.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in delegation context; no ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Add `--rebuild` (with `--dry-run`) to `/literature`'s mode-detection and delegation in `literature.md`.
- Add `handle_rebuild()` to `skill-literature/SKILL.md` with absent-sub-index deferral and an `AskUserQuestion` multiSelect job-picker (jobs 1 & 2 pre-checked by default).
- Implement Job 1 (dangling-ref lint) and Job 2 (structural-minimum schema conformance) by wiring up / adapting the existing dead "Sub-Index Management > Validate" block.
- Implement Job 4 (per-directory chunk/search-index coverage audit) with new read-only `sqlite3` queries handling both `sources/`-rooted and legacy `chunks_dir`-rooted schemas.
- Implement Job 3 (coverage refresh) as the only writer: LLM-driven candidate matching over `project_tags`/`keywords`/`summary`, an `AskUserQuestion`-gated diff/confirm, additions-only append via jq, never rewriting/deleting human curation.
- Verify end-to-end against cslib, BimodalLogic, and nvim (absent) sub-indexes.

**Non-Goals**:
- Fixing the `--convert`-never-chunks pipeline gap (Job 4 detects and reports it; repair is a separate follow-up).
- Populating the empty `document_metadata` table (flagged only; Job 4 queries `chunks_data`, not `document_metadata`).
- A top-level `/rebuild` command — `--rebuild` is a `/literature` sub-mode.
- Any automatic removal of dangling refs (removals remain a separate, explicitly confirmed action; no job removes anything).
- Editing the deployed copy under the deploy tree — extension source (`.claude/extensions/literature/`) is the sole source of truth.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Job 2 naively normalizes BimodalLogic's `reason`/`hazard`/`citation_rule`/`known_corrections`/`audits` away, destroying curation data | H | M | Structural-minimum check only (`doc_id` non-empty AND either `relevance` or `reason` present); never strip/flag extra fields; add explicit test against BimodalLogic's live sub-index asserting 0 violations |
| Job 4 directory→doc_id resolution wrong (parent/child fan-out, legacy `chunks_dir` schema, false positives) | H | M | Mirror `literature-fidelity-audit.sh`'s "Target entry resolution" root-vs-child fallback; handle both `sources/`-rooted and legacy `chunks_dir` entries; treat the 25-dir list as a starting point to spot-check |
| Job 3 (LLM matching) is a bigger lift than the mechanical jobs and could write without confirmation | H | M | Size Job 3 as its own phase; gate every write behind confirm-after-diff `AskUserQuestion`; append-only jq (never the "Remove" block); `--dry-run` skips confirm+write and only prints the proposed diff |
| `document_metadata` empty (0 rows) breaks any Job 4 logic that leans on it | M | L | Job 4 queries `chunks_data` exclusively; add a one-line note flagging the empty table |
| Edits land in deploy tree instead of extension source, tripping the #841 drift guard | M | L | All phases scope edits to `.claude/extensions/literature/`; verification runs the drift guard / `check-extension-docs.sh` |
| Job additions to `handle_rebuild()` collide (same SKILL.md region) if parallelized | M | M | Sequence the job phases (3 → 4 → 5); each is one agent run appending to the shared function |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |
| 5 | 6 | 1, 3, 4, 5 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch different files (`literature.md` vs `SKILL.md`) and are independent. Phases 3-5 all append to `handle_rebuild()` in the same SKILL.md region and are sequenced to avoid territory collisions.

---

### Phase 1: Command-layer wiring in `literature.md` [COMPLETED]

**Goal**: Route `--rebuild` (with `--dry-run`) through `/literature`'s mode-detection to `skill-literature` with `mode=rebuild`.

**Tasks**:
- [x] In `.claude/extensions/literature/commands/literature.md` step-1 mode-detection table, add `--rebuild` as a new priority-0 branch (before `--validate`), setting `sub_mode = "rebuild"`; make it mutually exclusive with `--validate`/`--index`/`--convert`. *(completed)*
- [x] Parse `--dry-run` alongside `--rebuild` (mirror how `--index`'s FILE arg is extracted); set `dry_run={true|false}`. *(completed)*
- [x] Add a row to the sub-mode summary table and to the Sub-Mode/FILE/QUERY validation table (`FILE Required: No`, `QUERY/TASK Required: No`). *(completed)*
- [x] Add a new `<step_X>` under `<workflow_execution>` delegating `skill: "skill-literature"`, `args: "mode=rebuild dry_run={true|false}"` (file arg unused). *(completed: added as `<step_3b>` to avoid renumbering existing step_4/step_5)*
- [x] Update the `argument-hint` frontmatter and the "Unknown flag" error message to list `--rebuild` (and `--dry-run`). *(completed)*

**Timing**: ~1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/commands/literature.md` — mode-detection table, sub-mode tables, workflow step, argument-hint, unknown-flag message.

**Verification**:
- `--rebuild` and `--rebuild --dry-run` resolve to `sub_mode=rebuild` with correct `dry_run` value.
- `--rebuild` does not collide with `--validate`/`--index`/`--convert` precedence.

---

### Phase 2: `handle_rebuild()` scaffold — dispatch, absent-sub-index deferral, job-picker [COMPLETED]

**Goal**: Add the `handle_rebuild()` container in SKILL.md: dispatch case, absent-sub-index routing, the multiSelect job-picker, report-aggregation shell, and `dry_run` plumbing — before any job logic.

**Tasks**:
- [x] In `.claude/extensions/literature/skills/skill-literature/SKILL.md` step-4 dispatch (`case "$mode" in status|scan|convert|validate|index|search|ingest|*)`), add `rebuild) handle_rebuild ;;` and add `rebuild` to the "Unknown mode" "Available:" list. *(completed)*
- [x] Add a `handle_rebuild()` function that reads `mode`/`dry_run` args. *(completed)*
- [x] Detect `! -f specs/literature-index.json` FIRST and defer to `literature-create-setup-task.sh` (invoke it or emit the same guidance the `--lit` flow uses via `literature-lit-flag-resolve.sh`'s `PROMPT_NEEDED`/`AUTONOMOUS_GLOBAL` precedent) — do NOT duplicate its state.json logic and do NOT error. *(completed)*
- [x] When the sub-index exists, present the `AskUserQuestion` multiSelect job-picker (`multiSelect: true`) with the four options from the research report; pre-check jobs 1 & 2 by default, leave 3 & 4 unchecked. *(completed)*
- [x] Add a report-aggregation shell that each selected job appends findings into (single multi-job report output), plus a `dry_run` note when active. *(completed)*

**Timing**: ~1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` — dispatch case, `handle_rebuild()` scaffold, job-picker, aggregation shell.

**Verification**:
- Against nvim (absent sub-index): `handle_rebuild()` routes to the create-setup-task path and never presents the picker or errors.
- Against cslib/BimodalLogic (present): the picker appears with jobs 1 & 2 pre-checked.
- `dry_run` value is threaded into the aggregation shell.

---

### Phase 3: Job 1 (dangling-ref lint) + Job 2 (structural-minimum schema conformance) [COMPLETED]

**Goal**: Wire up the existing dead "Sub-Index Management > Validate" block as Job 1, and add Job 2's structural-minimum + chunk-convention checks. Both read-only.

**Tasks**:
- [x] Lift the dead block (SKILL.md ~lines 1719-1753) into `handle_rebuild()` as **Job 1**: for each `doc_id` in `specs/literature-index.json`, assert `jq -e --arg id "$doc_id" '.entries[] | select(.id == $id)'` against `$LITERATURE_DIR/index.json`; shape output for the multi-job report (no standalone-command echo). *(completed: `rebuild_job1_dangling_ref_lint()`)*
- [x] Remove/neutralize the now-migrated dead block's stale `--subindex` help text so it is not doubly-defined. *(completed: Sub-Index Management > Validate section now points to Job 1)*
- [x] Add **Job 2** structural-minimum check: each entry has non-empty `doc_id` AND either `relevance` OR `reason`. Report entries missing even that minimum. Do NOT flag or strip extra fields (`hazard`, `citation_rule`, `known_corrections`, `audits`, `source`, `added`). *(completed: `rebuild_job2_schema_conformance()`)*
- [x] Add Job 2 `chunk-file-conventions.md` conformance check: assert no sub-index `doc_id` matches `^chunk_\d+$` or points at a `chunk_*.md` path (chunk files are index-only re-splits, never independently referenceable). *(completed: sub-index entries carry no path field, so the check is doc_id-pattern-only, matching the plan's `^chunk_\d+$` requirement)*
- [x] Ensure both jobs are gated by their picker selection and honor read-only/idempotent semantics. *(completed: gated via `run_job1`/`run_job2` in the aggregation shell; both jobs only read `$sub_index`/`$global_index`, never write)*

**Timing**: ~1.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` — Job 1 + Job 2 blocks inside `handle_rebuild()`; neutralize migrated dead block.

**Verification**:
- `--rebuild --dry-run` against cslib (11 entries) and BimodalLogic (2 entries): 0 dangling refs and 0 schema violations under the structural-minimum definition (BimodalLogic's extra fields NOT flagged).
- No `chunk_NNNN` false reference reported for either live sub-index.

---

### Phase 4: Job 4 (per-directory chunk/search-index coverage audit) [COMPLETED]

**Goal**: Add read-only Job 4 that reports, per directory, which converted documents lack FTS5 coverage — handling both schema layouts and quarantine hazards.

**Tasks**:
- [x] Add **Job 4** to `handle_rebuild()`: iterate every `sources/<dir>/` plus every legacy top-level `chunks_dir`-schema entry; check `SELECT count(*) FROM chunks_data WHERE doc_id = ...` per directory (query `chunks_data`, NOT the empty `document_metadata`). *(completed: `rebuild_job4_coverage_audit()`)*
- [x] Handle directory→doc_id resolution with parent/child fan-out (mirror `literature-fidelity-audit.sh`'s "Target entry resolution" root-vs-child fallback); handle legacy `chunks_dir`-keyed entries lacking a `path` field. *(deviation: altered — live-data verification (see implementation summary) showed `chunks_data.doc_id` is keyed on the `sources/<dir>/` directory basename itself, not on any `index.json` entry `.id`/`parent_doc` chain; the fidelity-audit's root/child fan-out logic answers a different question (which index.json entries to stamp) and does not apply to this doc_id lookup. Implemented as direct `doc_id = <directory basename>` / `doc_id = <legacy .doc_id>` checks instead, verified against live data to produce the exact expected 25-directory list.)*
- [x] Assert (defensively) that no directory's chunk set includes a chunked `.md.bak-*` / `.md.rejected` file (hazard b), and verify the chunker glob strictness assumption; report if violated. *(completed: grep against chunks.json manifests; live-verified 0 hits, glob-strictness assumption confirmed by reading literature-ingest.sh's `*.md` glob)*
- [x] Report the per-directory missing-coverage list (expected to surface the ~25 dirs) plus a one-line flag that `document_metadata` is empty and that the root cause is `--convert` not chunking (remediation out of scope). *(completed: live-verified exactly 25 directories reported, matching research baseline)*
- [x] Keep Job 4 strictly read-only and idempotent. *(completed: sqlite3 SELECT-only, jq read-only, grep read-only; no writes)*

**Timing**: ~1.5 hours

**Depends on**: 3

**Files to modify**:
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` — Job 4 block inside `handle_rebuild()`.

**Verification**:
- Job 4 run against the live corpus names the missing-coverage directories (should find ~25, including `girard_1989`, `rabinovich_2014`, `burgess_1982_i`).
- Legacy top-level `chunks_dir` entries are audited (not silently skipped).
- No corpus/DB mutation occurs.

---

### Phase 5: Job 3 (coverage refresh — the only writer) [COMPLETED]

**Goal**: Add Job 3: propose newly-relevant global-corpus docs absent from the sub-index, gate every write behind confirm-after-diff, and append additions-only via jq.

**Tasks**:
- [x] Add **Job 3** to `handle_rebuild()`: generate candidates by matching this repo's domain against global-index `project_tags`/`keywords`/`summary` (new LLM-driven matching; no existing script does this). *(completed: Rebuild Job 3 Step A, `project_tags`-based highest-confidence signal plus agent keyword/summary judgment)*
- [x] For each candidate, reuse the dead "Add" block's *validation* half only (confirm `doc_id` exists in the global index before proposing). *(completed: Rebuild Job 3 Step B)*
- [x] Present an `AskUserQuestion`-gated diff/confirm before any write; on confirm, append via the existing append-only jq pattern, writing `relevance` (do NOT overwrite or reshape existing entries; never use the "Remove" block). *(completed: Rebuild Job 3 Step C/D, `rebuild_job3_coverage_refresh()`)*
- [x] `--dry-run`: skip the confirm+write step; only print the proposed diff. Make explicit that `--dry-run` only changes Job 3 (1/2/4 never write regardless). *(completed: Step D returns before any write when dry_run=true)*
- [x] Ensure Job 3 never rewrites/deletes human curation and performs no automatic dangling-ref removal. *(completed: `.entries +=` append-only jq; explicit closing note that dangling-ref removal is always a separate, explicitly confirmed action)*

**Timing**: ~1.5 hours

**Depends on**: 4

**Files to modify**:
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` — Job 3 block inside `handle_rebuild()`.

**Verification**:
- `--rebuild --dry-run` with Job 3 selected: prints proposed additions, writes nothing.
- `--rebuild` with Job 3 confirmed: appends only, existing entries (including BimodalLogic's rich fields) untouched.
- No job mutates the corpus/sub-index without confirmation.

---

### Phase 6: End-to-end verification and wrap-up [COMPLETED]

**Goal**: Validate the full `--rebuild` flow against the three live cases and confirm no-write / drift-guard invariants.

**Tasks**:
- [x] Run `--rebuild --dry-run` against cslib (11 entries) and BimodalLogic (2 entries): confirm 0 dangling + 0 schema violations (structural-minimum) and BimodalLogic's extra fields not flagged. *(completed: live-executed the Job1/Job2 logic against both live sub-indexes; cslib 11 valid/0 orphans/0 violations, BimodalLogic 2 valid/0 orphans/0 violations including its `reason`/`hazard`/`citation_rule`/`known_corrections`/`audits` fields, sha256 unchanged before/after on both files)*
- [x] Run `--rebuild` against nvim (absent sub-index): confirm it routes to the create-setup-task path, not an error and not a job-picker. *(completed with a caveat: confirmed `specs/literature-index.json` is absent and traced/executed the Step-2 absence-detection control flow live; the actual invocation of `literature-create-setup-task.sh` was intentionally NOT executed for real, since it unconditionally mutates this repo's own live `specs/state.json`/TODO.md by creating a real task — doing so as a side effect of verification would pollute this repo's actual task list. Verified instead that state.json/TODO.md sha256 are unchanged after the control-flow trace, and that the script itself is pre-existing, unmodified, and already relied upon by the `--lit` flow, so its own correctness was not in question — only the new detection/delegation code was.)*
- [x] Run Job 4 against the live corpus: confirm it names the ~25 missing-coverage directories and audits legacy `chunks_dir` entries. *(completed: live-executed against `~/Projects/Literature` — 72 covered / 25 missing sources/<dir>/ directories matching the research baseline exactly (girard_1989, rabinovich_2014, burgess_1982_i, hodkinson_2006, tarjan_1972, thomas_1997, baier_katoen_2008, and 18 others); 11/11 legacy `chunks_dir` entries audited, 0 missing; 0 quarantine-artifact chunks found; `.literature.db`/global `index.json` sha256 unchanged before/after)*
- [x] Confirm no job (1/2/4, and Job 3 under `--dry-run`) mutates the corpus or any sub-index without confirmation. *(completed: sha256 before/after checks on cslib's and BimodalLogic's sub-indexes (Jobs 1/2), on the global `.literature.db`/`index.json` (Job 4), and on nvim's `state.json`/`TODO.md` (absent-sub-index path) all confirm zero mutation; Job 3's append-only jq snippet was separately verified against a scratch copy — not a live sub-index — to prove the write shape is correct without touching real data)*
- [x] Run the #841 drift guard / `.claude/scripts/check-extension-docs.sh` to confirm source-only edits and no deploy divergence. *(completed: `check-extension-docs.sh` reports the identical "FAIL: 6 issue(s) found" both before (git-stashed) and after this task's changes — all 6 are pre-existing issues in `core`/`lean`/`literature` extensions unrelated to `--rebuild` (missing `provides.scripts` manifest entries, undeployed lean sub-extensions). This task introduced zero new drift-guard failures; the two touched files, `literature.md` and `SKILL.md`, are extension-source-only edits per the task's file-scope constraint.)*
- [x] Optionally add a one-line note about `document_metadata`'s empty state to `.claude/context/project/literature/domain/literature-index.md` (per research recommendation; only if Job 4 references the table). *(completed: added a "Sub-Index Rebuild (--rebuild)" section covering the schema-divergence finding and the `document_metadata` empty-table note, since Job 4 explicitly queries `chunks_data` instead)*

**Timing**: ~1 hour

**Depends on**: 1, 3, 4, 5

**Files to modify**:
- (verification-only; optional one-line context note to `.claude/context/project/literature/domain/literature-index.md`)

**Verification**:
- All acceptance checks from the task's "VERIFICATION the plan must require" pass.
- `check-extension-docs.sh` exits zero.

---

## Testing & Validation

- [x] `--rebuild --dry-run` against cslib: 0 dangling, 0 schema violations (structural-minimum).
- [x] `--rebuild --dry-run` against BimodalLogic: 0 dangling, 0 schema violations; `reason`/`hazard`/`citation_rule`/`known_corrections`/`audits` NOT flagged or stripped.
- [x] `--rebuild` against nvim (absent sub-index): routes to `literature-create-setup-task.sh` path, not an error, no job-picker. *(control-flow verified live without executing the real state-mutating call — see Phase 6 task notes)*
- [x] Job 4 against live corpus: names the ~25 missing-coverage directories; audits legacy `chunks_dir` entries; queries `chunks_data` not `document_metadata`.
- [x] Jobs 1/2/4 are read-only and idempotent (re-running produces identical output, no writes). *(sha256-verified unchanged across two live runs each)*
- [x] Job 3 writes only after confirm-after-diff; `--dry-run` prints diff and writes nothing; no entry rewritten/removed. *(append-only jq shape verified against a scratch copy; dry-run branch returns before any write)*
- [x] No `chunk_NNNN` id is referenceable as a sub-index `doc_id`. *(Job 2's `^chunk_[0-9]+$` check verified 0 hits on both live sub-indexes)*
- [x] `.claude/scripts/check-extension-docs.sh` / #841 drift guard passes (source-only edits). *(0 new failures introduced — see Phase 6 task notes for the identical before/after 6-failure baseline)*

## Artifacts & Outputs

- `.claude/extensions/literature/commands/literature.md` (modified — `--rebuild` mode wiring)
- `.claude/extensions/literature/skills/skill-literature/SKILL.md` (modified — `handle_rebuild()` + 4 jobs)
- (optional) `.claude/context/project/literature/domain/literature-index.md` (one-line `document_metadata` note)
- specs/840_literature_rebuild_subindex_command/summaries/01_rebuild-summary.md (on completion)

## Rollback/Contingency

All changes are additive edits within the extension source (`.claude/extensions/literature/`). To revert, `git checkout` the two modified files (`literature.md`, `SKILL.md`) and the optional context note. Because jobs 1/2/4 are read-only and Job 3 writes only after explicit confirmation, no corpus or sub-index data is at risk from a partial implementation; an interrupted phase leaves `handle_rebuild()` incomplete but harmless (unreachable jobs simply do not run). Re-run the #841 drift guard after any revert to confirm source/deploy parity.
