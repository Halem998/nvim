# Implementation Plan: Unify the literature global-index schema and end stub-entry invisibility

- **Task**: 77 - Unify the literature global-index schema and end stub-entry invisibility
- **Status**: [IMPLEMENTING]
- **Effort**: 12 hours
- **Dependencies**: 32 (redeploy — already satisfied)
- **Research Inputs**: specs/077_unify_literature_global_index_schema/reports/01_unify-literature-global-index-schema.md
- **Artifacts**: plans/01_unify-global-index-fts-namespace.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The literature global index (`~/Projects/Literature/index.json`) and the FTS database
(`~/Projects/Literature/.literature.db`, `chunks_data.doc_id`) are two independent id namespaces
that have drifted apart on 49 documents, and `literature-ingest.sh` still writes a stub entry
that neither `literature-briefing.sh` nor the curated schema recognizes. This plan fixes the
writer, bridges the two namespaces **without renaming anything** (renaming was tried by hand and
broke `--toc`), repairs the small residue of index/FTS disagreements in the corpus repo, and adds
a `--validate` conformance check plus regression tests so the class cannot recur silently.

The organizing decision is that **`sources/<dir>/` in an entry's `.path` is the bridge between the
two namespaces**: the directory-name component of a `sources/`-prefixed path *is* the
`chunks_data.doc_id`. This is not a new invention — `literature-search.sh` already derives its
fidelity-map key exactly this way at four sites. Measured against the live corpus, the path-derived
key covers **202 of 204** FTS doc_ids where `.id` covers only 172. Bridging by path is therefore a
code-only fix for the majority of the divergence, with zero data migration and zero id renames.

Definition of done: a freshly ingested document is resolvable in a briefing with real
title/authors/year and a chunk count that matches `--toc`; a project-filtered search returns
documents whose curated `.id` differs from their FTS `doc_id`; `/literature --validate` fails
loudly on a divergent entry; and both behaviours are covered by executed regression tests.

### Research Integration

The report established four binding constraints this plan is built around:

1. **The obvious fix is known-broken.** Renaming an ingest-written bare id to the curated long
   form makes the briefing resolve *and* makes `literature-search.sh --toc` return `[]`, because
   FTS keys on the bare id fixed at chunk time. This plan never renames a live FTS id. Every
   id-touching phase below carries execution-based verification (`--toc` plus a project-filtered
   search) precisely because code reading did not reveal this defect — running the command did.
2. **Four namespaces must be reconciled together**: index `.id`, ingest's `doc_id`,
   `chunks_data.doc_id`, and the parent/child chunk-granularity split.
3. **A second, independent breakage**: `literature-search.sh`'s `get_project_doc_ids()` builds its
   allow-list from `.id` but filters `chunks_data.doc_id`, so all 49 disagreeing documents vanish
   from project-tag-filtered search — the path `literature-briefing.sh --global` exercises.
4. **`/literature --validate` drives its loop off `.path`**, so a stub entry becomes the literal
   string `"null"` and is misreported as a missing *file* rather than a schema-shape defect.

Planning-time re-measurement (2026-08-24, live corpus, `HEAD` = `e6ce8bd9`) confirmed the report's
numbers unchanged and refined them:

```
index entries                                      399
entries with .id == null                             0   <- criterion 2 already satisfied
parent entries (.id set, parent_doc null/empty)    189
FTS distinct chunks_data.doc_id                    204
present in both (.id space)                        172
FTS-only  (no parent entry under that id)           32
index-only (no FTS chunks under that id)            17

coverage of FTS doc_ids by .id                     172 / 204
coverage of FTS doc_ids by path-derived dir key    202 / 204   <- the bridge
```

Refinement of the 49: **17 of the 32 FTS-only ids already have a curated parent entry whose
`.path` points into their directory** (`blackburn_2002` <- `blackburn_2002_book`, `girard_1989` <-
`proofs_and_types`, `thomas_2003_reactive` <- `thomas_2003_ch01`/`ch03`, …). Only **15** FTS-only
directories have no parent entry at all. Two FTS doc_ids (`proofs_and_types`,
`van_doorn_2015_propositional_calculus_coq`) are duplicate ingests of works already indexed under
another directory. One index dir key (`gabbay_2000`) has no FTS chunks because its conversion was
rejected (`sources/gabbay_2000/` holds only a `.rejected` file and the source PDF). The
reconciliation residue is therefore small and enumerable, not a 49-document migration.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `specs/ROADMAP.md` in this repository; `specs/PATH.md` Stage 2 "Literature plumbing" is the
sequencing context — two downstream tasks depend on this one, so the writer fix and the
`--validate` check are the load-bearing deliverables for them.

## Decisions

The research report left three forks open. All three are settled here, with rationale.

### Decision A — New ingests move under `sources/<id>/`. SETTLED: yes.

`literature-ingest.sh` currently writes to `$LITERATURE_DIR/$DOC_ID/` (top level). New ingests
move to `$LITERATURE_DIR/sources/$DOC_ID/`.

Rationale:
- **The corpus is already fully consolidated there.** Measured: 0 of 399 index entries have a
  `.path` that is not `sources/`-prefixed. Continuing to write top-level would make new ingests the
  *only* non-conforming entries in the corpus, and would break the path-derived bridge this whole
  plan rests on.
- **FTS is placement-agnostic**, so there is no migration risk on the search side:
  `literature-build-index.sh` discovers manifests with a recursive `find "$target_dir" -name
  chunks.json`, so the database is rebuilt identically wherever the directory sits. This was the
  unenumerated back-compat concern the report flagged; it is now confirmed a non-issue.
- **It switches on fidelity stamping for free.** `literature-fidelity-audit.sh` targets
  `sources/<dir>/` exclusively and documents in its own header that entries outside `sources/`
  "are never matched or written". Placing new ingests under `sources/` makes them eligible for
  `provenance_fidelity` with zero code change there — which is what makes acceptance criterion 3
  (`get_doc_fidelity()` returns a real value rather than the fail-open default) actually reachable
  for newly ingested documents.
- Same argument covers `literature-search.sh`'s four `prefix = "sources/"` fidelity-map sites.

Cost, and the reason this is a decision rather than a formality: `literature-ingest.sh`'s own
`DOC_DIR` references and its `--local` copy step must move together, and `metadata.json`'s
`chunks_dir` (an absolute path) must follow. Nothing else in the extension assumes the old
top-level layout.

### Decision B — Chunk granularity for new writes. SETTLED: 1:1 with `chunks.json` / FTS rows.

A new ingest writes one parent entry (`parent_doc: null`, `path: "sources/<id>/"`) plus **one child
entry per chunk** in `chunks.json` (`parent_doc: "<id>"`, `path: "sources/<id>/chunk_NNNN.md"`).

Rationale:
- **The briefing's count and `--toc`'s count then agree by construction** for every document
  ingested going forward. Today they cannot: `baier_katoen_2008` reports "12 chunk(s), ~590624
  tokens" in the briefing and 1263 chunks under `--toc`.
- **The advertised unit becomes an actually-readable file.** The coarse part-level granularity
  makes the briefing advertise ~229 KB "chunks"; an agent trusting that count will try to read one.
- **It is a mechanical projection, not metadata synthesis.** `literature-chunk.sh` already emits
  `title`, `keywords`, `summary`, `token_count`, and `source_path` per chunk, so every field a
  child entry needs already exists in `chunks.json`.
- Coarser, human-curated part granularity remains legitimate for hand-curated legacy entries. It
  must not be what a script produces unattended.

**Explicitly out of scope**: retrofitting the ~12 legacy part-granularity books. They are already
adjudicated, they resolve in both paths today, and their counts are a cosmetic inconsistency
rather than an invisibility.

### Decision C — Reconciliation strategy for the 17 index-only documents. SETTLED: bridge by path; never rename; add parent entries only where no index coverage exists at all.

Neither re-chunking under the curated id nor renaming the curated id to the bare id. Instead:

- **General rule (code):** the directory component of a `sources/`-prefixed `.path` IS the FTS
  `doc_id`. Any reader that must address FTS derives its key from `.path`, falling back to `.id`
  only when the path is absent or not `sources/`-prefixed. `.id` stays free to be the curated,
  human-facing name. Nothing is renamed, so `--toc` and `--read` are untouched by construction.
  This single change takes project-filtered-search coverage from 172/204 to 202/204 and closes
  breakage (3) for **all 14 paired index-only documents plus the 17 FTS-only documents that share
  their directories** — 31 of the 49 — with no data change whatsoever.
- **Data residue (corpus repo), enumerated:**
  - **15 FTS-only directories with no parent entry** (`burgess_1982`, `burgess_1982b`,
    `burgess_1984`, `derijke_1995`, `doets_1987`, `doets_1989`, `obendrauf_2024`, `reynolds_1992`,
    `reynolds_1994`, `thomason_1984`, `venema_1991`, `venema_1997`, `venema_2001`,
    `verbrugge_2004`, `xu_1988`): add a parent entry **under the bare directory id** — the exact
    operation validated by hand in corpus commit `e6ce8bd9`.
  - **2 duplicate chunk directories** (`sources/proofs_and_types/` duplicating
    `sources/girard_1989/`; `sources/van_doorn_2015_propositional_calculus_coq/` duplicating
    `sources/van_doorn_2015/`): adjudicate to one directory each, remove the loser's `chunks.json`,
    rebuild FTS.
  - **1 index entry with no chunks** (`gabbay_2000`, conversion rejected): re-convert, or stamp
    `provenance_fidelity: not_yet_converted` and record it as a known FTS-absent entry.
  - **The 14 paired index-only entries: NO ACTION.** Leaving a curated `.id` that differs from its
    FTS `doc_id` is now a *supported* configuration, not a defect, because the path bridge resolves
    it. Renaming them is the specific operation known to break `--toc`.

Rationale for choosing the bridge over re-indexing: re-chunking 14 documents under curated ids
would rewrite ~thousands of FTS rows, invalidate every existing `chunk_id` reference held in
consuming repos' sub-indices and research artifacts, and buy nothing the path derivation does not
already provide. The bridge is reversible, data-free, and testable by execution.

### Decision D (secondary, per report) — `.doc_id` reader fallback in `literature-briefing.sh`

Included, but scoped explicitly as defense-in-depth **behind** the writer fix (Phases 4-6), never
as a substitute for it. A reader-only patch would reproduce the "backfill the symptom, not the
cause" pattern the task addenda warn against.

## Goals & Non-Goals

**Goals**:
- `literature-ingest.sh` writes a canonical, briefing-resolvable entry keyed by the same bare id
  `literature-chunk.sh` stamps into FTS, under `sources/<id>/`, with 1:1 chunk children and real
  metadata where available.
- Project-filtered search (`literature-search.sh --project`, the path `--global` briefing uses)
  returns documents whose curated `.id` differs from their FTS `doc_id`.
- `literature-briefing.sh` tolerates both key shapes and stops silently skipping stub entries.
- `/literature --validate` detects schema-shape defects and index/FTS namespace divergence, and
  reports them as such rather than as missing files.
- The enumerated corpus residue (15 + 2 + 1) is reconciled in the corpus repo.
- Regression tests cover ingest-then-brief, the `--validate` divergence check, and the
  project-filtered-search bridge.
- The id/FTS invariant is written down so the next person is not tempted to "clean up" an id.

**Non-Goals**:
- No backfill of stub entries — measured 0 remaining; criterion 2 is satisfied by inspection.
- No renaming of any live FTS `doc_id`, ever, by any phase.
- No retrofit of legacy part-granularity books to 1:1 children.
- No changes to `zotero-attach-chunks.sh`, `zotero-generate-export.sh`, or
  `literature-normalize-authors.sh` — the reader survey confirmed all three operate in unrelated
  namespaces.
- No refactor of `literature-search.sh`'s four existing inline `prefix = "sources/"` python sites;
  they already implement the bridge correctly and are cited as precedent, not rewritten.
- No work in `~/Projects/Literature/` outside the enumerated residue in Decision C.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A phase renames an id and re-breaks `--toc` invisibly | H | M | Every id-touching phase (2, 3, 4, 5, 8) requires executed `--toc` + project-filtered-search verification against a fixed probe set captured in Phase 1. Reading the script is explicitly not acceptable evidence. |
| Editing the deployed `.claude/` tree instead of the source store; the edit is wiped on next reload | H | M | All code edits target `agent-system/extensions/literature/**`. Verification invokes the **source-store** scripts by absolute path, not the deployed copies, so a green result cannot come from a stale deploy. |
| `--validate` divergence check lights up all existing disagreements at once with no triage | M | H | Phase 7 ships the check in WARN mode with the Phase 1 baseline recorded as a known-exceptions count; Phase 10 escalates to hard failure only after Phase 8 reconciliation. |
| Corpus counts drift between planning and implementation (repaired out of band from another repo) | M | M | Phase 1 re-measures everything before any change and is a hard prerequisite for every other phase; every count in this plan carries a Scope Hypothesis line. |
| `sources/` placement move breaks the ingest `--local` copy path | M | M | Phase 4 is scoped to placement only and is verified by an end-to-end ingest of a small fixture PDF, including the `--local` step. |
| Corpus data edits are made in the wrong repo or committed into this one | H | L | Phase 8 is explicitly flagged as operating in `~/Projects/Literature/` (a separate git repo), with its own commit, and touches no file under this repository. |
| 1:1 children inflate `index.json` substantially for large documents | L | M | Measured worst case is ~1263 children for one book; entry count grows but the file stays JSON-manageable. Phase 5 records the post-ingest entry-count delta for one real document. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4 | 1 |
| 3 | 5, 7 | 2, 4 |
| 4 | 6, 8 | 3, 5, 7 |
| 5 | 9 | 6, 8 |
| 6 | 10 | 9 |

Phases within the same wave can execute in parallel. Waves 2's three phases touch three disjoint
files (`literature-search.sh`, `literature-briefing.sh`, `literature-ingest.sh`) and are
territory-safe for parallel dispatch.

---

### Phase 1: Re-measure the corpus and freeze an execution baseline [COMPLETED]

**Goal**: Replace every count in this plan with a freshly measured one, and capture the
before-state of the two commands that must not regress, so later phases have something to diff
against.

**Tasks**:
- [x] Record `git -C ~/Projects/Literature log --oneline -1` and `git status --short` (confirm the
      corpus tree is clean before any change). *(completed: tree NOT clean — pre-existing uncommitted leftover from separate completed task 080_exclude_backups_from_literature_index_rebuild, unrelated to this task; recorded in 02_baseline-measurements.md)*
- [x] Measure: total entries; `[.entries[] | select(.id == null)] | length`; parent-entry count;
      `SELECT COUNT(DISTINCT doc_id) FROM chunks_data`. *(completed: 399/0/189/204, matches plan exactly)*
- [x] Compute the three divergence sets (FTS-only, index-only, both) and the path-derived-key
      coverage of FTS doc_ids. Confirm or correct: 32 / 17 / 172, and 202 vs 172 coverage. *(completed: confirmed exactly, no correction needed)*
- [x] Re-enumerate the Decision C residue: FTS-only dirs with no parent entry (expected 15),
      duplicate chunk directories (expected 2), index dir keys with no FTS chunks (expected 1). *(completed: confirmed 15/2/1 exactly)*
- [x] Capture BEFORE output for a fixed 5-document probe set spanning the failure modes — at
      minimum `blackburn_2002` (paired FTS id), `blackburn_2002_book` (paired curated id),
      `burgess_1982` (FTS-only, no parent), `gabbay_2000` (index-only, no chunks), and one
      document present in both namespaces as a control:
      - `literature-search.sh --toc <id>` for each
      - `literature-search.sh --project <repo> "<query>"` for a query known to hit at least one
        curated-id document *(completed: control = alpern_schneider_1985_defining-liveness; query = --project BimodalLogic "bisimulation")*
- [x] Write all of the above to `specs/077_unify_literature_global_index_schema/reports/02_baseline-measurements.md`. *(completed)*
- [x] If the null-`.id` count is still 0, record acceptance criterion 2 as satisfied by inspection
      and confirm no backfill work is scheduled anywhere in this plan. *(completed: 0 confirmed, no backfill scheduled)*

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This plan asserts 399 entries / 0 null-id / 189 parents / 204 FTS doc_ids /
32 FTS-only / 17 index-only / 15-2-1 residue / 202-vs-172 coverage, measured at corpus `HEAD`
`e6ce8bd9`. Confirm each by executing the measurements above. If any differs, update the counts in
this plan's Overview and in Decision C's enumerated lists **before** starting Phase 8, and record
the delta in the baseline report.

**Files to modify**:
- `specs/077_unify_literature_global_index_schema/reports/02_baseline-measurements.md` - new
  measurement artifact (task-management artifact, not a deliverable)

**Verification**:
- The baseline report exists and contains executed command output, not summarized prose.
- The probe-set BEFORE output is captured verbatim; at least one probe returns `[]` or a skip
  warning (proving the baseline captures the defect, not a healthy system).

---

### Phase 2: Path-derived FTS key bridge in `literature-search.sh` [COMPLETED]

**Goal**: Close breakage (3) — project-filtered search silently excluding every document whose
curated `.id` differs from its FTS `doc_id` — by deriving the allow-list key from `.path` rather
than from `.id` alone.

**Tasks**:
- [x] Create `agent-system/extensions/literature/scripts/literature-doc-key.sh`: the single sourced
      anchor for the index-entry -> FTS-key derivation. Expose (a) a sourceable function taking an
      index path and emitting the derived key set, and (b) a `--list-keys <index.json>` CLI mode so
      non-bash consumers (SKILL.md, tests) can call it. Derivation: if `.path` starts with
      `sources/`, the key is the first path component after that prefix; otherwise fall back to
      `.id`. Document in the file header that this mirrors the four existing inline
      `prefix = "sources/"` sites in `literature-search.sh`, which are deliberately left in place. *(completed)*
- [x] Rewire `get_project_doc_ids()` to emit the **union** of the path-derived key and `.id` for
      each matching entry. Union, not replacement: the result feeds a `WHERE d.doc_id IN (...)`
      filter, so an extra key with no FTS rows is inert, while dropping a key can silently hide a
      document. Iterate `.entries[]?` (children included) — that is what pulls in the directories
      whose only index coverage is at child level. *(completed)*
- [x] Add a header comment recording the invariant: **the allow-list must live in the
      `chunks_data.doc_id` namespace, never the curated `.id` namespace.** *(completed)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the union key set raises project-filtered-search coverage
of FTS doc_ids from 172/204 to 202/204. Confirm by executing `--list-keys` against the live index,
intersecting with `SELECT DISTINCT doc_id FROM chunks_data`, and comparing to the Phase 1 baseline
number — not by inspecting the jq expression.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-doc-key.sh` - new sourced anchor
- `agent-system/extensions/literature/scripts/literature-search.sh` - `get_project_doc_ids()` rewired

**Verification** (BY EXECUTION — reading the script is not acceptable evidence):
- Run the Phase 1 probe-set `--toc` commands against the source-store script. Every one returns
  **byte-identical** output to the Phase 1 baseline: this phase must not perturb `--toc` at all.
- Run `literature-search.sh --project <repo> "<query>"` for the Phase 1 query. At least one
  document whose curated `.id` differs from its FTS `doc_id` (e.g. content under `blackburn_2002`)
  now appears where the baseline returned nothing.
- Run the one-hop dependent by execution: `literature-briefing.sh --global` (or
  `literature-briefing-invoke.sh` in global mode) and confirm it returns results for the same
  query, since it calls `literature-search.sh --project` internally.
- Run `literature-doc-key.sh --list-keys` and confirm the derived-key/FTS intersection matches the
  Scope Hypothesis number.

---

### Phase 3: Reader tolerance and comment repair in `literature-briefing.sh` [COMPLETED]

**Goal**: Make the briefing resolve a stub-shaped entry (`.doc_id` present, `.id` absent) instead
of silently skipping it, and correct the header comment that asserts a now-false invariant.

**Tasks**:
- [x] At all three `.id`-only lookup sites — `get_doc_fidelity()` (~114), the parent lookup with
      the `parent_doc` filter (~175), and the fallback lookup (~181) — accept either key:
      `select((.id // .doc_id) == $id ...)`, mirroring the pattern `literature-discover.sh`
      already uses at its Tier 1 lookup (`.id // .doc_id // ""`). *(completed: grep for `select(.id ==` found 9 total hits, not 3 -- the 3 named lookup sites plus 5 metadata-extraction sites (title/authors/year/token_count x2) = 8 fixed; the 9th (path-resolution, ~238) is the explicitly-excluded site below)*
- [x] Apply the same tolerance to the title / authors / year / `token_count` extraction jq
      expressions so a `.doc_id`-resolved entry does not degrade to "Unknown Title" after the
      lookup succeeds. *(completed: 5 sites -- title, authors, year, parent_tokens, total_tokens)*
- [x] Rewrite the header comment (~105-107) that asserts all lookups are "keyed by index.json's
      `.id` field": state the real contract — `.id` preferred, `.doc_id` tolerated, and the FTS
      `doc_id` derived from `.path`, never from `.id`. *(completed)*
- [x] Do **not** touch the path-resolution block (~227-246). The report's fourth-addendum
      correction is explicit: it already prefers `.path` over an id-derived guess and is not an
      offender on this axis. *(completed: verified untouched, still reads `select(.id == $id)` at ~238)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly three `.id ==`-only lookup sites plus the
metadata-extraction expressions. Confirm by grepping the file for `select(.id ==` and enumerating
every hit before editing; if the count differs from three lookup sites, fix all of them and record
the corrected list in the phase notes.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-briefing.sh` - three lookup sites,
  metadata extraction, header comment

**Verification** (BY EXECUTION):
- Build a throwaway fixture global index containing one stub-shaped entry (`doc_id` set, `.id`
  absent) and a sub-index referencing it; run `literature-briefing-invoke.sh` against it with
  `LITERATURE_DIR` pointed at the fixture. Assert: zero `not found in global index — skipping`
  warnings on stderr, and the document's title/authors/year appear in the output.
- Run the same invocation against the **live** corpus and confirm the skip-warning count is not
  higher than the Phase 1 baseline (currently expected 0).
- Confirm `get_doc_fidelity()` returns a real value, not `unverified_summary`, for a fixture entry
  carrying `provenance_fidelity` under a `.doc_id`-only key.

---

### Phase 4: Move new ingests under `sources/<id>/` (Decision A) [COMPLETED]

**Goal**: Land the filesystem-placement half of the writer fix on its own, so that a placement
regression is isolated from the index-schema change that follows.

**Tasks**:
- [x] In `literature-ingest.sh`, change `DOC_DIR="$LITERATURE_DIR/$DOC_ID"` to
      `DOC_DIR="$LITERATURE_DIR/sources/$DOC_ID"`, and ensure `mkdir -p` creates the intermediate
      `sources/` level. *(completed: two DOC_DIR sites -- BASE_DOC_ID provisional assignment and the post-conversion actual-DOC_ID assignment -- both moved; mkdir -p already creates intermediates)*
- [x] Update `metadata.json`'s `chunks_dir` to follow the new location. *(completed: chunks_dir is written from $DOC_DIR directly, follows automatically)*
- [x] Audit and update the `--local` copy step and any later `DOC_DIR`-derived path in the same
      script (including the summary output) for the new layout. *(completed: DOC_SRC in the --local loop updated to sources/<id>/; summary output prints doc_ids only, no path, no change needed)*
- [x] Update the pipeline comment block in the script header to state the `sources/` placement and
      the reason (fidelity-audit targeting + path-derived FTS bridge). *(completed)*
- [x] Confirm by execution that `literature-build-index.sh --global` still discovers the new
      manifest — its recursive `find ... -name chunks.json` is placement-agnostic, but this must be
      demonstrated on a real ingest, not assumed. *(completed: end-to-end fixture ingest, DB rebuilt with 1 chunk indexed under sources/phase77_fixture_doc/)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts that no code outside `literature-ingest.sh` assumes the
old top-level `$LITERATURE_DIR/$DOC_ID/` layout (measured: 0 of 399 index entries use a
non-`sources/` path). Confirm by grepping the whole extension for `LITERATURE_DIR/\$DOC_ID` and
`LITERATURE_DIR"/"` patterns before editing, and record the hit list.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-ingest.sh` - `DOC_DIR`, `metadata.json`
  write, `--local` copy step, header comment

**Verification** (BY EXECUTION):
- Ingest a small fixture PDF end to end against a scratch `LITERATURE_DIR`. Assert the chunks land
  at `<scratch>/sources/<id>/chunk_0001.md` and `<scratch>/sources/<id>/chunks.json`, and that
  nothing is written at `<scratch>/<id>/`.
- Assert `.literature.db` in the scratch dir contains rows with `doc_id = <id>` after the ingest's
  own `literature-build-index.sh --global` step.
- Run `literature-search.sh --toc <id>` against the scratch corpus and confirm it returns the
  chunks (not `[]`) — the placement move must not disturb the FTS id.
- Run the `--local` step and confirm the copy lands correctly under `specs/literature/`.

---

### Phase 5: Canonical index-entry write with 1:1 chunk children (Decisions B + C) [COMPLETED]

**Goal**: Replace the 8-field stub write in `literature-ingest.sh` Step 4 with a canonical parent
entry keyed by the bare FTS id, plus one child entry per chunk.

**Tasks**:
- [x] Rewrite the Step 4 python heredoc to emit a **parent** entry: `id` = `$DOC_ID` (the same bare
      id `literature-chunk.sh` stamped into `chunks.json` — never a longer curated form),
      `doc_id` = the same value (belt-and-braces back-compat, matching the 35 existing dual-keyed
      entries), `parent_doc: null`, `path: "sources/<id>/"`, `token_count` (document total),
      `chunk_count`, `doc_type`, `source_format`, `keywords`, `summary`, `ingested_at`,
      `source_path`. *(deviation: altered — token_count set to 0, not document total; see phase notes)*
- [x] Emit one **child** entry per row in `chunks.json`: `id` = the chunk's `chunk_id`,
      `parent_doc` = `$DOC_ID`, `path` = `"sources/<id>/<source_path>"`, and `title`, `keywords`,
      `summary`, `token_count` projected straight from the chunk record. *(completed: keywords converted string->array to match established index.json convention)*
- [x] Make the pre-write removal idempotent across re-ingest: remove the existing parent entry
      **and all its children** for this `doc_id` before appending, matching on either `.id` or
      `.doc_id` and on `parent_doc == $DOC_ID`. *(completed: verified by execution -- re-ingest of the same fixture produced 7 entries both times, no duplicates, no orphans)*
- [x] Keep the `title`/`authors`/`year` placeholders honest for now — bare id / `[]` / `null` — and
      leave real metadata to Phase 6. Do not fabricate values. *(completed)*
- [x] Add an inline comment recording the anti-rename invariant at the point where `id` is
      assigned: **the id written here MUST equal `chunks_data.doc_id`; renaming it to a curated
      long form breaks `--toc` and project-filtered search.** *(completed)*

**Timing**: 2 hours

**Depends on**: 2, 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts every field a 1:1 child entry needs already exists in
`chunks.json` (`chunk_id`, `title`, `keywords`, `summary`, `token_count`, `source_path`). Confirm
by dumping one real `chunks.json` record and checking each field is present and populated before
writing the projection; if any is missing, record which and decide explicitly whether to omit it
or derive it, rather than emitting a null.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-ingest.sh` - Step 4 python heredoc,
  Step 3 `metadata.json` shape alignment

**Verification** (BY EXECUTION):
- Ingest the Phase 4 fixture into a scratch corpus. Assert the resulting `index.json` has exactly
  one parent entry with `.id == <id>` and `parent_doc == null`, and exactly `chunk_count` children
  with `parent_doc == <id>`.
- `literature-search.sh --toc <id>` chunk count **equals** the number of index children — the
  granularity decision's whole point, and the assertion that must not be waived.
- `literature-briefing-invoke.sh` against a sub-index naming `<id>` resolves it with zero skip
  warnings and reports the same chunk count as `--toc`.
- `literature-search.sh --project <name> "<query>"` returns the fixture document.
- Re-ingest the same fixture and assert the entry count is unchanged (idempotence: no duplicate
  parent, no orphaned children).
- Record the `index.json` entry-count delta for one real document (risk-table mitigation).

---

### Phase 6: Real title / authors / year from Zotero in the ingest path [COMPLETED]

**Goal**: Close the metadata-degradation half of acceptance criterion 1 — a briefing should render
"To Be F Is To Be G (2016) — Cian Dorr", not "dorr_2016_to_be_f_is_to_be_g (?) — ".

**Tasks**:
- [x] Thread the resolved Zotero key (already available on the `--zotero <key>` path) through the
      per-file loop to Step 4. *(completed: $ZOTERO_KEY is already set from arg parsing before the per-file loop; threaded into a new Step 3b lookup and into the parent entry as `zotero_key`)*
- [x] Look up title / authors / year via `zotero-read.sh` and populate the parent entry, including
      `zotero_key` so `zotero-attach-chunks.sh` and `zotero-resolve-pdf.sh` can resolve the entry
      later. *(completed: verified by execution with a real Zotero key -- see phase notes)*
- [x] For local-PDF ingests with no Zotero match, emit an **honest partial**: keep the bare id as
      `title` but stamp a field marking the metadata as unresolved so `--validate` and a human can
      see the difference between "not yet enriched" and "enriched to these values". Never fabricate
      an author or year. *(completed: `metadata_status` field, "resolved"|"unresolved"; verified by execution)*
- [x] Ensure the `authors` value is a proper array of individual author strings — the shape
      `/literature --validate`'s existing authors-shape check enforces — not a comma-joined string. *(completed: individual "First Last" strings per author creator, editors excluded; verified 0 authors-shape warnings against the fixture)*

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase assumes `zotero-read.sh` exposes title/authors/year for a given
key in a form directly consumable here. Confirm by executing it against one real key and inspecting
the output shape before writing the integration; if the shape differs, adapt rather than assuming.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-ingest.sh` - Zotero key threading, Step 4
  metadata population

**Verification** (BY EXECUTION):
- Ingest one document via `--zotero <key>` into a scratch corpus; assert the parent entry carries
  the real title, an authors array with individual entries, a numeric year, and `zotero_key`.
- Run `literature-briefing-invoke.sh` and confirm the rendered line shows the real
  title/authors/year rather than the bare id and `(?)`.
- Ingest one local PDF with no Zotero match; assert the honest-partial marker is present and no
  fabricated author or year appears.
- Run the existing `--validate` authors-shape check against the scratch index; it must pass.

---

### Phase 7: `/literature --validate` schema-conformance and namespace-divergence check [COMPLETED]

**Goal**: Fix the `.path`-driven loop that misreports a schema defect as a missing file, and add
the id-vs-`chunks_data.doc_id` set comparison (acceptance criteria 5 and 7) — in WARN mode.

**Tasks**:
- [x] In `skills/skill-literature/SKILL.md` Validate Step 1, stop driving the loop off
      `jq -r '.entries[] | .path'`. Iterate `.entries[]` as whole records (e.g. compact JSON per
      line) so an entry lacking `.path` is seen as an entry, not as the literal string `null`. *(completed)*
- [x] Add a schema-shape bucket, reported separately from stale entries: entries missing `.id`,
      missing `.path`, or carrying a `.path` that is not `sources/`-prefixed. The existing
      `null (missing)` misreport must be gone. *(completed: verified by execution -- see phase notes)*
- [x] Add the namespace-divergence check: read `SELECT DISTINCT doc_id FROM chunks_data` from
      `$LITERATURE_DIR/.literature.db` via `sqlite3` (following `literature-search.sh`'s existing
      pattern), derive the index-side key set via `literature-doc-key.sh --list-keys`, and report
      three buckets — FTS doc_ids with no index coverage; index dir keys with no FTS chunks;
      parent entries whose `.id` is neither its own path-derived key nor present in FTS. *(completed: bucket 3 gated on the dir-key ALSO failing to resolve in FTS, so the 17 supported paired entries Decision C names are correctly excluded -- see phase notes for the fixture proof)*
- [x] Ship the divergence check as **WARN**, printing the Phase 1 baseline counts as a documented
      known-exceptions figure and naming the phase that escalates it. Do not fail the command yet —
      the corpus residue is not reconciled until Phase 8. *(completed: exit 0 confirmed by execution in all fixture and live-corpus runs)*
- [x] Keep the existing stale-entry, token-drift, required-field, and authors-shape checks working
      unchanged under the new loop. *(completed: verified by execution against the live corpus -- schema_warnings populated as before, e.g. missing doc_type/source_format on legacy entries)*

**Timing**: 2 hours

**Depends on**: 2

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the current loop misreports a `.path`-less entry as
`null (missing)`. Confirm by executing the *current* validate flow against a fixture index
containing one stub entry and observing the literal `null (missing)` line **before** editing —
the defect must be reproduced, not inferred from the jq expression.

**Files to modify**:
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` - Validate Steps 1-2
- `agent-system/extensions/literature/scripts/literature-doc-key.sh` - `--list-keys` consumed here
  (no change expected; confirm the CLI contract suffices)

**Verification** (BY EXECUTION):
- Against a fixture index with one stub entry: validate reports it in the **schema-shape** bucket
  with its `doc_id` named, and the string `null (missing)` does not appear anywhere in the output.
- Against a fixture with a deliberately mismatched id/FTS pair: the divergence check reports it.
- Against the live corpus: the three divergence buckets match the Phase 1 baseline counts exactly
  (expected 15 / 1 / 0 after path derivation, but take Phase 1's measured numbers as authoritative).
- The command still exits 0 in WARN mode.

---

### Phase 8: Reconcile the enumerated corpus residue (separate repo — `~/Projects/Literature/`) [NOT STARTED]

**Goal**: Bring the data into agreement with the invariant, so Phase 10 can escalate `--validate`
to a hard failure.

**MANUAL / SCRIPTED DATA STEP — NOT A SOURCE-STORE EDIT.** Every change in this phase lands in
`~/Projects/Literature/`, which is a **separate git repository**. Nothing in this phase modifies a
file under this repository. Commit the corpus changes in that repo, on its own, with a message
describing the reconciliation; do not stage them here.

**Tasks**:
- [ ] Confirm the corpus tree is clean and record its `HEAD` before starting (out-of-band repairs
      arrive from other repos).
- [ ] For each of the 15 FTS-only directories with no parent entry, add a parent entry **under the
      bare directory id** — generalizing corpus commit `e6ce8bd9`. Prefer a small script over 15
      hand edits, but review the generated diff entry by entry before committing.
- [ ] Adjudicate the 2 duplicate chunk directories (`proofs_and_types` vs `girard_1989`;
      `van_doorn_2015_propositional_calculus_coq` vs `van_doorn_2015`): pick the survivor per pair,
      remove the loser's `chunks.json` (and its chunk files, or move them to a dot-prefixed
      quarantine directory, which `literature-build-index.sh` prunes by design), and record the
      choice and its reason.
- [ ] Adjudicate `gabbay_2000` (index entry, conversion rejected, no chunks): either re-convert and
      re-ingest, or stamp `provenance_fidelity: not_yet_converted` and record it as a known
      FTS-absent entry in the `--validate` known-exceptions note.
- [ ] Take **no action** on the 14 paired index-only entries. Record that explicitly in the commit
      message: leaving a curated `.id` that differs from its FTS `doc_id` is supported by the path
      bridge, and renaming it is the specific operation known to break `--toc`.
- [ ] Rebuild the global FTS database (`literature-build-index.sh --global`) after the directory
      adjudications.

**Timing**: 2 hours

**Depends on**: 3, 7

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts a 15 / 2 / 1 residue. Phase 1's measured numbers override
these. If Phase 1 found a different residue, reconcile what Phase 1 enumerated — do not work this
plan's list from memory.

**Files to modify**:
- `~/Projects/Literature/index.json` - add 15 parent entries; adjudicate `gabbay_2000` (separate repo)
- `~/Projects/Literature/sources/proofs_and_types/`, `~/Projects/Literature/sources/van_doorn_2015_propositional_calculus_coq/` - duplicate adjudication (separate repo)
- `~/Projects/Literature/.literature.db` - rebuilt artifact (separate repo)

**Verification** (BY EXECUTION):
- `literature-search.sh --toc <id>` for each of the 15 newly-parented ids returns chunks (not
  `[]`), and for each of the 5 Phase 1 probe documents returns output consistent with the baseline
  except where this phase intentionally changed it.
- `literature-briefing-invoke.sh` against a sub-index naming all 15 resolves all 15 with zero skip
  warnings.
- `literature-search.sh --project <name> "<query>"` returns at least one of the newly-parented
  documents.
- The Phase 7 `--validate` divergence buckets are now empty except for the explicitly recorded
  `gabbay_2000`-class exception.
- `git -C ~/Projects/Literature status --short` shows only the intended files;
  `git -C /home/benjamin/.config/nvim status --short` shows no corpus files at all.

---

### Phase 9: Regression tests in `test-lit-pipeline.sh` (acceptance criterion 6) [NOT STARTED]

**Goal**: Make all three fixed behaviours executable assertions, so the defect class cannot
regress silently. The existing Section E fixture uses one id for both namespaces and has therefore
never been able to catch this class.

**Tasks**:
- [ ] Case 1 (ingest-then-brief): fixture the **actual post-fix** `literature-ingest.sh` output
      shape — parent + 1:1 children under `sources/<id>/` — register it in a per-repo sub-index,
      run `literature-briefing-invoke.sh`, and assert the document appears with correct
      title/authors/year and a chunk count equal to `--toc`'s.
- [ ] Case 2 (`--validate` divergence): fixture an index whose parent `.id` has no corresponding
      `chunks_data.doc_id` and whose `.path` does not bridge to one; assert the divergence check
      reports it.
- [ ] Case 3 (project-filtered-search bridge): fixture a document whose curated `.id` differs from
      its FTS `doc_id` but whose `.path` is `sources/<fts_id>/`; assert
      `literature-search.sh --project` returns it. This is the guard for Phase 2 — the breakage
      that had no test at all.
- [ ] Case 4 (schema-shape): fixture a stub entry lacking `.id`/`.path`; assert `--validate`
      classifies it as a schema-shape defect and that `null (missing)` never appears.
- [ ] Change the shared fixture so the global-index `.id` and the sub-index `doc_id` are **not**
      trivially identical in at least one case, so a future `.id`-only regression fails a test.
- [ ] Confirm the companion coverage-marker assertion (a deliberately-unresolvable `doc_id` drives
      the coverage marker to report the failure rather than `sparse=false`) is scheduled in its own
      task; record where. The task description binds this task's test to that one.

**Timing**: 2 hours

**Depends on**: 6, 8

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts Section E is the right home and that four new cases
suffice. Confirm by reading the current Section E structure first; if the harness makes a sibling
section cleaner, use one and say so.

**Files to modify**:
- `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` - Section E extension or a new
  sibling section

**Verification** (BY EXECUTION):
- The full `test-lit-pipeline.sh` suite passes.
- Each new case is demonstrated to **fail** when its fix is reverted (revert in the working tree,
  run, confirm red, restore). A test that cannot be shown to fail is not evidence.

---

### Phase 10: Escalate `--validate` to hard failure and document the invariant [NOT STARTED]

**Goal**: Turn the divergence check into a gate now that the corpus conforms, and write the
invariant down where the next person will find it before they rename an id.

**Tasks**:
- [ ] Flip the Phase 7 divergence check from WARN to a hard failure, carrying forward only the
      explicitly enumerated known exceptions from Phase 8 (the `gabbay_2000` class), each with a
      recorded reason.
- [ ] Add an FTS-namespace subsection to
      `agent-system/extensions/literature/context/project/literature/domain/literature-index.md`
      recording: the `chunks_data.doc_id` namespace; the invariant that an entry's FTS key is the
      directory component of its `sources/`-prefixed `.path`; the **never rename a live FTS id**
      rule with the concrete `--toc`-returns-`[]` consequence; the `sources/` placement /
      fidelity-audit-targeting interaction; and the 1:1 chunk-granularity rule for script-written
      entries. Cite `literature-doc-key.sh` as the single sourced anchor.
- [ ] Update `literature-fidelity-audit.sh`'s header note: entries outside `sources/` are still
      never matched, but new ingests now land inside `sources/`, so the exclusion no longer covers
      the ingest pipeline.
- [ ] Complete the reader-survey record (acceptance criterion 4): for each surveyed script, state
      fixed / not-an-offender / deliberate-exclusion, in the domain doc.
- [ ] Note that the source-store changes reach `.claude/` only on the next deploy; all verification
      in this plan invoked source-store scripts by absolute path, so no phase depended on a deploy.

**Timing**: 1.5 hours

**Depends on**: 9

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the corpus fully conforms after Phase 8 apart from the
enumerated exceptions. Confirm by running `--validate` in the escalated mode against the live
corpus and observing a clean exit **before** declaring the phase done; a non-empty divergence
bucket means Phase 8 is unfinished, not that the check should be softened.

**Files to modify**:
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` - WARN -> FAIL escalation
- `agent-system/extensions/literature/context/project/literature/domain/literature-index.md` - FTS
  namespace invariant, never-rename rule, reader-survey record
- `agent-system/extensions/literature/scripts/literature-fidelity-audit.sh` - header note

**Verification** (BY EXECUTION):
- `/literature --validate` (source-store flow) exits clean against the live corpus.
- It exits non-zero against the Phase 9 Case 2 fixture.
- The domain doc contains no task-number references (deliverable rule), and states the
  never-rename invariant explicitly.

---

## Testing & Validation

- [ ] `test-lit-pipeline.sh` passes in full, including the four new cases.
- [ ] Each new test case is demonstrated red-then-green against a reverted fix.
- [ ] End-to-end scratch ingest: chunks under `sources/<id>/`, parent + 1:1 children in
      `index.json`, FTS rows under the same bare id.
- [ ] `literature-search.sh --toc <id>` chunk count equals the index child count for every
      newly-ingested document.
- [ ] `literature-briefing-invoke.sh` resolves every sub-index entry with **zero** skip warnings
      (the task's stated concrete verification).
- [ ] `literature-search.sh --project <name> "<query>"` returns a document whose curated `.id`
      differs from its FTS `doc_id`.
- [ ] Every Phase 1 probe-set `--toc` command returns output consistent with the baseline, except
      where Phase 8 intentionally changed it.
- [ ] `/literature --validate` exits clean against the live corpus and non-zero against the
      mismatched fixture.
- [ ] No file under a deployed `.claude/` tree was edited by any phase.

## Artifacts & Outputs

- `specs/077_unify_literature_global_index_schema/plans/01_unify-global-index-fts-namespace.md` (this plan)
- `specs/077_unify_literature_global_index_schema/reports/02_baseline-measurements.md` (Phase 1)
- `agent-system/extensions/literature/scripts/literature-doc-key.sh` (new sourced anchor)
- Modified: `literature-search.sh`, `literature-briefing.sh`, `literature-ingest.sh`,
  `literature-fidelity-audit.sh`, `test-lit-pipeline.sh`,
  `skills/skill-literature/SKILL.md`,
  `context/project/literature/domain/literature-index.md` — all under
  `agent-system/extensions/literature/`
- Separate repo (`~/Projects/Literature/`): 15 added parent entries, 2 duplicate-directory
  adjudications, 1 `gabbay_2000` adjudication, rebuilt `.literature.db`

## Rollback/Contingency

- **Source-store code**: each phase commits independently, so any phase reverts with a single
  `git revert` in this repository. Phases 2, 3, 4 are on disjoint files and revert independently of
  one another.
- **Corpus data (Phase 8)**: commits land in `~/Projects/Literature/`, which was confirmed clean at
  Phase 1 and at Phase 8 start. Revert there with `git revert` in that repo, then rerun
  `literature-build-index.sh --global` to rebuild the ephemeral database. The database is derived
  from chunk files on disk and is never the thing to restore.
- **`--validate` escalation (Phase 10)**: if the escalated check proves too strict in practice, the
  contingency is to return it to WARN with the divergence counts still printed — never to remove
  the check. Silence is the defect this plan exists to end.
- **If any phase's execution verification cannot be run** (corpus unavailable, `sqlite3` missing),
  mark that phase `[BLOCKED]` rather than substituting a code read for a command run. The one
  defect this task's history proves is invisible to code reading is exactly the one being fixed.
