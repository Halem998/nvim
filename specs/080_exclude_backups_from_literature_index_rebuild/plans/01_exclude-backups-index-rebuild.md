# Implementation Plan: Stop the literature index rebuild from indexing backed-up chunk manifests

- **Task**: 80 - Stop the literature index rebuild from indexing backed-up chunk manifests
- **Status**: [IMPLEMENTING]
- **Effort**: 5.5 hours
- **Dependencies**: None blocking. Sequenced-after advisory on the literature global-index schema-unification task (see Risks) — that task shares `literature-build-index.sh` in its file scope but none of this plan's four scope items touch `index.json` entry shape.
- **Research Inputs**: `specs/080_exclude_backups_from_literature_index_rebuild/reports/01_exclude-backups-from-index-rebuild.md`
- **Artifacts**: plans/01_exclude-backups-index-rebuild.md (this file)
- **Standards**:
  - `.claude/context/formats/plan-format.md`
  - `.claude/context/standards/status-markers.md`
  - `.claude/rules/artifact-formats.md`
  - `.claude/rules/state-management.md`
  - `.claude/rules/source-store-deploy-boundary.md`
  - `.claude/rules/no-task-references-in-deliverables.md`
- **Type**: meta
- **Lean Intent**: false

## Overview

`literature-build-index.sh`'s manifest discovery (`find "$target_dir" -name "chunks.json" | sort`)
has no prune guard, so every rebuild descends into `.backups/` and any other dot-prefixed
directory and indexes superseded chunk manifests as if they were live. This plan adds a
root-and-nested dot-directory prune to that one traversal, makes a doc_id claimed by two
manifests loud instead of silent, replaces the counter-derived rebuild stats with
database-derived per-doc_id counts, locks all three in with a scratch-directory regression test,
documents the "live corpus directory" predicate in a new context file, and finally proves the
manual `chunks.json.bak` rename workaround is unnecessary by reverting all 14 renames and
rebuilding clean. Definition of done: a global rebuild with intact `chunks.json` files present
under `.backups/` produces a byte-equivalent chunk_id set to a rebuild with `.backups/` absent,
and the pre-existing stale chunk in the live database is gone.

### Research Integration

Findings carried directly into phase design:

- **Confirmed defect site**: `literature-build-index.sh:91` is the only unguarded recursive
  traversal in the extension; every other traversal is `-maxdepth 1` or `-maxdepth 2`, and
  `literature-search.sh` performs no traversal at all. Phase 6 re-runs and records this survey
  rather than assuming it (acceptance criterion 4 requires it *completed*).
- **Corrected audit method (acceptance criterion 3)**: see "Correction to acceptance criterion 3"
  below — the literal `source_path LIKE '%.backups%'` query the criterion describes is
  structurally incapable of finding anything.
- **Duplicate-doc_id precedent**: `literature-ingest.sh` warns-then-overwrites on a duplicate
  `doc_id` at the `index.json` layer. Phase 3's policy is reconciled against that precedent
  explicitly (see "Decision: duplicate-doc_id policy" below), not decided in isolation.
- **Exclusion shape**: dot-prefixed directories generally, not a `.backups` literal — the
  corpus root already holds `.sources-recovered/` and `.online-ingest-staging/` alongside
  `.backups/`.

### Correction to acceptance criterion 3 (stated explicitly, as required)

Acceptance criterion 3 asks for an audit of "stale `source_path` values pointing into
`.backups/`". **That audit is unsatisfiable as literally worded and would report clean regardless
of actual corruption.** `chunks_data.source_path` stores a bare filename relative to its own
manifest's directory (`chunk_0001.md`), never an absolute or manifest-rooted path, and the schema
has no column recording which manifest a row was built from. A `LIKE '%.backups%'` query returns
zero rows on a corrupt database exactly as it does on a clean one.

**Substituted method**: a per-`doc_id` chunk_id-set diff — every `chunk_id` in `chunks_data` that
is absent from the current live manifest for that `doc_id` is a stale survivor, whatever
directory produced it. Phase 1 runs this diff as the pre-fix baseline and Phase 7 re-runs it to
assert zero. A future reader should not conclude the literal query was tried and passed trivially;
it was never a valid test.

### Decision: duplicate-doc_id policy (scope direction 2)

**Chosen: loud warning by default, naming the `doc_id` and every claiming manifest path, plus an
opt-in `--strict-duplicates` flag that makes it fatal (exit 3).**

Reconciliation with the `literature-ingest.sh` warn-then-overwrite precedent: the default
**matches** that precedent rather than diverging from it, and the divergence is confined to the
opt-in flag. Rationale for not making fatal the default:
`skill-literature`'s convert flow already invokes `literature-build-index.sh` in a
non-fatal `|| echo "Warning ... non-fatal"` wrapper, so a hard failure there does not surface as
"one document is ambiguous" — it surfaces as *the entire global index silently not rebuilt*,
leaving every document stale. That is strictly worse than indexing the union and shouting about
it. The strict flag exists so the regression test and any future CI gate can assert detection
deterministically.

This is a reversible decision: flipping the default to fatal is a one-line change to the flag's
initial value plus a documentation edit, if the operator prefers hard failure.

### Live finding that reshapes Phase 1 and Phase 3 (measured 2026-08-24)

The research report states the live database is currently clean. **It is not.** A direct
manifest-vs-database diff run during planning found a real, present instance of the defect class:

- `sources/thomas_2003_reactive/` has a live top-level `chunks.json` (36 chunks) **and** two
  superseded per-chapter manifests under `sources/thomas_2003_reactive/.chunks/` (12 and 24
  chunks, dated ~2 weeks earlier) that claim the same `doc_id`.
- The live database holds **37** chunks for `thomas_2003_reactive` — 36 live plus **one stale
  survivor** whose `chunk_id` exists only in the superseded `.chunks/ch03` manifest.
- This is therefore also a live duplicate-`doc_id` case: fatal-by-default would break the very
  next global rebuild until the exclusion lands, which is why Phase 3 is sequenced strictly after
  Phase 2.

Two consequences for the exclusion's shape:

1. The prune must apply to dot-prefixed directories **at any depth**, not only at the corpus
   root — `.chunks/` sits three levels down.
2. Verified safe: no `doc_id` in the corpus is reachable *only* through a dot-prefixed directory
   (206 manifests by bare `find`, 204 after the prune, 204 distinct `doc_id`s either way, and the
   204 database `doc_id`s match the pruned manifest set exactly). `.chunks/` is a one-off legacy
   artifact — no script in the extension writes to it.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap path was supplied in the delegation context; no ROADMAP.md was consulted.

## Goals & Non-Goals

**Goals**:
- A rebuild with an intact `chunks.json` present under `~/Projects/Literature/.backups/` produces
  the same chunk_id set as a rebuild with that directory absent (acceptance criterion 1).
- Two manifests claiming one `doc_id` produce a loud, both-paths-named warning by default and a
  hard failure under `--strict-duplicates`; the choice is documented (acceptance criterion 2).
- The live database is audited by chunk_id-set diff and cleaned by a rebuild (acceptance
  criterion 3, as corrected above).
- The traversal survey is re-run and recorded, and the exclusion predicate is expressed once, in
  one documented place (acceptance criterion 4).
- All 14 `chunks.json.bak` renames under `.backups/` are reverted and the corpus rebuilds clean,
  proving nothing depends on an operator remembering the workaround (acceptance criterion 5).
- Rebuild output reports database-derived per-`doc_id` counts, so a 99-vs-144 mismatch is visible
  at rebuild time (scope direction 4).

**Non-Goals**:
- Populating the dormant `document_metadata` table. It is defined in `literature-schema.sql` and
  never written by `literature-build-index.sh` (zero rows live). Wiring it up is a separate
  concern; per-`doc_id` reporting goes to the existing stderr stats line instead.
- A full diff-against-prior-index mechanism (requires retaining the prior database or a
  snapshot). Per-`doc_id` counts plus the manifest-vs-database mismatch warning cover the
  observed failure mode at far lower cost.
- Adding a `source_manifest_dir` provenance column to `chunks_data`. It would make a literal
  `source_path`-style audit possible in future, but it is a schema change that collides with the
  schema-unification task and is not needed for the chunk_id-diff audit.
- Any change to `literature-search.sh`, `literature-audit.sh`, `literature-ingest.sh`, or
  `literature-ingest-online.sh` — the survey confirms none of them has an unguarded traversal.
- Fixing the latent `doc_chunks_by_label` scoping bug in the cross-reference resolution pass
  (the dict is built inside the per-manifest loop but read after it, so only the last manifest's
  labels survive). Noted here so it is not mistaken for a regression introduced by this work;
  it predates this plan and is out of scope.
- Editing anything under `.claude/**`. All edits target `agent-system/extensions/literature/**`;
  redeploying is the operator's action.

### Declared file-scope expansion

The task's declared `file_scope` names one file. This plan deliberately expands it to four, each
justified:

| File | Status | Why |
|------|--------|-----|
| `agent-system/extensions/literature/scripts/literature-build-index.sh` | declared | The defect site |
| `agent-system/extensions/literature/scripts/tests/test-literature-build-index.sh` | **new** | Acceptance criterion 1 requires a regression test; follows the existing `tests/test-literature-convert.sh` pattern |
| `agent-system/extensions/literature/manifest.json` | **expansion** | `provides.scripts` enumerates every shipped script including `tests/*`; an unregistered test file is not deployed |
| `agent-system/extensions/literature/context/project/literature/domain/corpus-directory-conventions.md` | **new** | Acceptance criteria 2 and 4 require the predicate and the duplicate policy to be documented and shared rather than rediscovered |

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Dot-directory prune silently drops a live manifest reachable only through a dot-prefixed path | H | L | Already measured: 206 -> 204 manifests, zero `doc_id` lost, database `doc_id` set unchanged. Phase 2 re-runs this exact before/after comparison as its verification, and Phase 5 asserts it in the regression test |
| A dot-named `--dir` target (e.g. `--dir ~/Projects/Literature/.backups`) self-prunes and indexes nothing | M | M | The prune expression uses `-mindepth 1` so the starting point is never tested. Verified during planning: explicitly targeting `.backups` still finds its 14 manifests |
| Fatal-on-duplicate would break the next global rebuild (a live duplicate exists today) | H | H (if fatal chosen as default) | Default is warn; Phase 3 is sequenced strictly after Phase 2, which removes the only live duplicate |
| Reverting the 14 `.bak` renames mutates the operator's corpus outside version control | M | L | Phase 7 records the exact rename mapping to a file under the task directory *before* renaming, making the step exactly reversible, and asserts the post-rebuild chunk_id set is identical to the pre-rename baseline |
| The schema-unification task also lists `literature-build-index.sh` in its file scope; whichever lands second must rebase | M | M | Nothing in this plan touches `index.json` entry shape or the schema file. If that task lands first, re-verify line numbers (they drift) before editing; the phases are otherwise independent |
| Editing `.claude/scripts/literature-build-index.sh` instead of the source store | H | L | Source-store rule is restated in every phase's file list; `.claude/**` is a disposable deploy artifact |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 3 |
| 4 | 5, 6 | 4 |
| 5 | 7 | 1, 5, 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Baseline Audit of the Live Database [COMPLETED]

**Goal**: Record the pre-fix state of `~/Projects/Literature/.literature.db` using the corrected
chunk_id-set diff method, so Phase 7 has a concrete before/after to assert against.

**Tasks**:
- [x] Enumerate live manifests with the *bare* (current, unguarded) `find` and with the proposed
      dot-pruned `find`; record both counts and the set difference *(completed)*
- [x] For each `doc_id`, build the live-manifest `chunk_id` set and diff it against
      `SELECT chunk_id FROM chunks_data WHERE doc_id = ?`; record every `chunk_id` present in the
      database but absent from the live manifest (stale survivors) and vice versa *(completed)*
- [x] Record every `doc_id` claimed by more than one manifest, with all claiming paths *(completed)*
- [x] Record the 14 `chunks.json.bak` paths under `.backups/` verbatim *(completed)*
- [x] Write all of the above to `specs/080_exclude_backups_from_literature_index_rebuild/reports/01_pre-fix-audit.txt` *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: Planning-time measurement (2026-08-24) found 206 manifests by bare `find`,
204 after dot-pruning, 204 distinct `doc_id`s, exactly one `doc_id`
(`thomas_2003_reactive`) claimed by three manifests, exactly one stale `chunk_id` in the database
(37 rows vs 36 live chunks), and 14 `chunks.json.bak` files under `.backups/`. Every one of these
is a hypothesis, not a fact: the corpus is live and may have changed. Confirm each by running the
audit and record the actual numbers; if they differ, the actual numbers govern and Phase 7's
assertions must be re-derived from them.

**Files to modify**:
- `specs/080_exclude_backups_from_literature_index_rebuild/reports/01_pre-fix-audit.txt` - new,
  audit output (task-management artifact, not a deliverable)

**Verification**:
- The audit file exists, is non-empty, and names each stale `chunk_id` with its `doc_id`
- The bare-vs-pruned manifest sets differ only by paths containing a dot-prefixed component
- No `doc_id` appears in the pruned manifest set's complement (i.e. no document is lost by pruning)

---

### Phase 2: Exclude Dot-Prefixed Directories from Manifest Discovery [COMPLETED]

**Goal**: Replace the unguarded traversal with a prune that skips dot-prefixed directories at any
depth, without self-pruning a dot-named `--dir` target.

**Tasks**:
- [x] Re-verify the traversal's current line number before editing (line numbers drift) *(completed)*
- [x] Replace the `mapfile -t manifests < <(find "$target_dir" -name "chunks.json" | sort)` line
      with the pruned form:
      `find "$target_dir" -mindepth 1 \( -name '.*' -type d -prune \) -o \( -name 'chunks.json' -print \) | sort` *(completed)*
- [x] Add a comment above the traversal naming what the prune excludes and why (backups,
      quarantine, staging, and VCS/tooling directories are not live corpus), and pointing at the
      context file Phase 6 creates *(completed)*
- [x] Update the script's header comment block to state that dot-prefixed directories are excluded
      from discovery and that a dot-named `--dir` target is still indexed when named explicitly *(completed)*
- [x] Log the excluded-manifest count when it is non-zero
      (e.g. `Found N manifests (M skipped in non-corpus directories)`) so the exclusion is visible
      rather than silent *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the prune changes discovery from 206 to 204 manifests on
the live corpus and loses no `doc_id`. Confirm by running both `find` forms against
`~/Projects/Literature` and diffing the sorted outputs, and by confirming the `doc_id` set of the
pruned result equals the `doc_id` set of the bare result.

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-build-index.sh` - pruned traversal,
  comment, header, skipped-count log line. **Not** `.claude/scripts/literature-build-index.sh`

**Verification**:
- `bash -n` passes on the edited script
- `shellcheck` reports no new findings relative to the pre-edit baseline *(deviation: skipped —
  shellcheck is not installed in this environment; substituted `bash -n` plus the scratch
  functional tests below)*
- Bare `find` and pruned `find` outputs diff only by dot-component paths; `doc_id` sets are equal
  *(confirmed: live-corpus diff is exactly the two `.chunks/` manifests under
  `sources/thomas_2003_reactive/`, matching the Phase 1 audit)*
- A scratch-directory run (`--dir <tmp>` with a planted `.backups/<label>/chunks.json`) indexes
  only the live manifest *(confirmed)*
- Explicitly targeting a dot-named directory (`--dir ~/Projects/Literature/.backups` against a
  scratch copy) still discovers its manifests — the `-mindepth 1` guard works *(confirmed)*

---

### Phase 3: Detect and Report Duplicate doc_id Across Manifests [NOT STARTED]

**Goal**: Make a `doc_id` claimed by two or more manifests loud and named, with an opt-in fatal
mode, per the decision recorded in the Overview.

**Tasks**:
- [ ] Add a `--strict-duplicates` flag to the argument parser (default off) and thread it into
      `build_index_for_dir` and the Python block
- [ ] In the Python block, before the insert loop, map `doc_id -> [manifest_path, ...]` across all
      discovered manifests
- [ ] For each `doc_id` with more than one claiming manifest, emit a warning naming the `doc_id`
      and every claiming path on its own line, plus the per-manifest chunk count for each
- [ ] Under `--strict-duplicates`, exit non-zero after reporting all duplicates (report every
      duplicate first, then fail once — do not fail on the first)
- [ ] Reserve and document exit code 3 for "duplicate doc_id under --strict-duplicates" in the
      header's exit-code list
- [ ] Ensure the non-strict path still builds the index and still exits 0, matching the
      `literature-ingest.sh` warn precedent

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-build-index.sh` - flag parsing,
  duplicate map, warning emission, exit code 3, header exit-code documentation

**Verification**:
- `bash -n` passes
- Scratch run with two manifests sharing a `doc_id`: default mode warns with both paths named and
  exits 0; `--strict-duplicates` reports both and exits 3
- Scratch run with three manifests sharing a `doc_id` reports all three paths, not just two
- A global rebuild against the live corpus (post-Phase-2) reports zero duplicates — the
  `.chunks/` case is excluded by the prune

---

### Phase 4: Report Database-Derived Per-doc_id Counts [NOT STARTED]

**Goal**: Replace counter-derived rebuild stats with counts read back from the database, and warn
when a manifest's declared chunk count does not match what landed, so an inflated count is visible
at rebuild time.

**Tasks**:
- [ ] Replace the `total_chunks` counter in the summary line with
      `SELECT COUNT(*) FROM chunks_data`, and additionally report the insert-attempt count so
      replaces are visible as the difference (an attempt count exceeding the row count is the
      exact signal the original 144-vs-99 report should have carried)
- [ ] Add a `SELECT doc_id, COUNT(*) FROM chunks_data GROUP BY doc_id` pass after commit
- [ ] Compare each `doc_id`'s database row count against the chunk count declared by its live
      manifest; emit a per-`doc_id` warning line for every mismatch, naming both numbers
- [ ] Report distinct-`doc_id` count alongside the total in the existing stderr summary line
- [ ] Keep full per-`doc_id` enumeration off by default (mismatches only) so the summary stays
      readable across 204 documents

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: local

**Files to modify**:
- `agent-system/extensions/literature/scripts/literature-build-index.sh` - stats block after the
  insert/commit pass

**Verification**:
- `bash -n` passes
- Scratch run with a planted stale manifest (pre-exclusion behavior simulated by targeting the
  backup directory directly) prints a mismatch line naming the declared and actual counts
- Clean scratch run prints no mismatch lines and a total equal to the sum of live manifest lengths
- Live global rebuild's reported total equals `SELECT COUNT(*) FROM chunks_data` on the resulting
  database

---

### Phase 5: Regression Test [NOT STARTED]

**Goal**: Lock acceptance criterion 1 in a test that plants a backup manifest and asserts the
index is identical to one built without it, so the defect cannot silently return.

**Tasks**:
- [ ] Create `tests/test-literature-build-index.sh` following the `tests/test-literature-convert.sh`
      pattern: `mktemp -d` scratch directory, `trap ... EXIT` cleanup, PASS/FAIL counters, exit 1
      on any required failure. The suite MUST NOT read from or write to `~/Projects/Literature/`
- [ ] Fixture: a live `<doc>/chunks.json` plus `.backups/<label>/chunks.json` for the same
      `doc_id`, with one overlapping `chunk_id` and one `chunk_id` present only in the backup
      (the stale-survivor case that no `INSERT OR REPLACE` can clean up)
- [ ] Test A (criterion 1): run `--dir <scratch>` with the backup present, then with it removed;
      assert both runs yield an identical `chunk_id` set and identical per-`doc_id` counts
- [ ] Test B: assert the stale-only `chunk_id` from the backup is absent from the built database
- [ ] Test C: assert a dot-prefixed directory nested below the top level (the `.chunks/` shape) is
      also excluded, not just a root-level one
- [ ] Test D: assert `--dir` pointed *directly* at a dot-named directory still indexes it
      (`-mindepth 1` guard)
- [ ] Test E (criterion 2): two live manifests sharing a `doc_id` — default run warns with both
      paths named and exits 0; `--strict-duplicates` exits 3
- [ ] Test F (scope direction 4): a mismatch between declared and actual chunk count produces the
      per-`doc_id` warning line
- [ ] Register both the test in `manifest.json` `provides.scripts` as `tests/test-literature-build-index.sh`
- [ ] Make the test executable

**Timing**: 1.25 hours

**Depends on**: 4

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly two files change (one new test file, one
`manifest.json` edit) and that `provides.scripts` is the only manifest key needing an entry.
Confirm by inspecting `manifest.json`'s existing `tests/test-literature-convert.sh` registration
and matching its shape exactly; if the deploy tooling reads any additional key for test files,
that key must be updated too.

**Files to modify**:
- `agent-system/extensions/literature/scripts/tests/test-literature-build-index.sh` - new
- `agent-system/extensions/literature/manifest.json` - add the test to `provides.scripts`

**Verification**:
- The suite runs green from a clean checkout and exits 0
- Reverting the Phase 2 prune (temporarily, in the working tree) makes Test A, B, and C fail —
  proving the test actually exercises the fix rather than passing vacuously. Restore the prune
  afterward
- `jq . manifest.json` parses; the new entry matches the existing `tests/` entry's shape
- `git status` confirms nothing under `~/Projects/Literature/` was touched by the test run

---

### Phase 6: Document the Predicate, the Policy, and the Traversal Survey [NOT STARTED]

**Goal**: Give the "live corpus directory" predicate, the duplicate-`doc_id` policy, and the
traversal survey one documented home so future scripts inherit them instead of rediscovering them.

**Tasks**:
- [ ] Create `context/project/literature/domain/corpus-directory-conventions.md` covering:
      which directories under the corpus root are live vs. backup/quarantine/staging; the exact
      prune expression and why it uses `-mindepth 1`; the `.chunks/` legacy case as the worked
      example of a *nested* non-corpus directory; and the instruction that any future recursive
      traversal over the corpus must use the same predicate
- [ ] Document the duplicate-`doc_id` policy in the same file: warn-by-default with all claiming
      paths named, `--strict-duplicates` for exit 3, the reconciliation with
      `literature-ingest.sh`'s warn-then-overwrite precedent, and why fatal is not the default
      (a non-fatal caller wrapper turns a hard failure into a silently un-rebuilt index)
- [ ] Re-run the traversal survey (`grep -n 'find ' scripts/*.sh` plus a `glob`/`os.walk` grep over
      `*.py`) and record the resulting table in the same file, with the explicit finding that no
      other script needs the predicate today
- [ ] Record that `literature-search.sh` performs no traversal and inherits corruption only
      through the database, so it needs no change
- [ ] Update `context/project/literature/domain/format-decision.md`'s description of manifest
      discovery if it states the traversal is unguarded
- [ ] Reference durable anchors (filenames, section headings) only — no task-number references in
      any file outside `specs/**`

**Timing**: 0.75 hours

**Depends on**: 4

**Verification Tier**: prose

**Files to modify**:
- `agent-system/extensions/literature/context/project/literature/domain/corpus-directory-conventions.md` - new
- `agent-system/extensions/literature/context/project/literature/domain/format-decision.md` - only
  if its manifest-discovery description is now stale

**Verification**:
- Every changed hunk lies in markdown prose; no script behavior changes in this phase
- `bash .claude/scripts/check-task-references.sh` (or equivalent repo lint) reports no
  task-number references introduced outside `specs/**`
- The recorded survey table matches a freshly-run grep, not the research report's copy
- The prune expression quoted in the doc is character-identical to the one in the script

---

### Phase 7: Eliminate the .bak Workaround and Verify the Live Corpus [NOT STARTED]

**Goal**: Prove acceptance criteria 1, 3, and 5 against the real corpus: revert every manual
`chunks.json.bak` rename, rebuild, and show the index is unchanged and the stale survivor is gone.

**Tasks**:
- [ ] Record the exact list of `chunks.json.bak` paths under `.backups/` to
      `specs/080_exclude_backups_from_literature_index_rebuild/reports/01_bak-rename-mapping.txt`
      **before** renaming anything, so the step is exactly reversible
- [ ] Back up the current `~/Projects/Literature/.literature.db` to a timestamped sibling before
      the rebuild
- [ ] Rename every recorded `chunks.json.bak` back to `chunks.json`
- [ ] Run `literature-build-index.sh --global` from the source store and capture its full stderr
- [ ] Re-run the Phase 1 audit: assert zero stale `chunk_id`s and zero duplicate `doc_id`s
- [ ] Assert `thomas_2003_reactive` now has exactly its live-manifest chunk count (36 at planning
      time), down from 37
- [ ] Assert the rebuilt database's `chunk_id` set equals the pre-rename baseline's `chunk_id` set
      minus the stale survivors — i.e. reverting the workaround changed nothing except removing
      staleness (this is acceptance criterion 1 proven on the real corpus, not just in the test
      fixture)
- [ ] Assert the rebuild's reported manifest count reflects the skipped-manifest log line from
      Phase 2
- [ ] Append the results to `reports/01_pre-fix-audit.txt` as a post-fix section, or write
      `reports/01_post-fix-audit.txt`

**Timing**: 1.25 hours

**Depends on**: 1, 5, 6

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts 14 `.bak` files are renamed and that
`thomas_2003_reactive` drops from 37 to 36 rows. Both are planning-time measurements over a live,
mutable corpus. Confirm the `.bak` count by `find` immediately before renaming and re-derive the
expected `thomas_2003_reactive` count from its live manifest at run time rather than hardcoding
36. If the corpus has changed, the Phase 1 audit's actual numbers govern.

**Files to modify**:
- `~/Projects/Literature/.backups/**/chunks.json.bak` -> `chunks.json` (corpus mutation outside
  the repository; mapping recorded first)
- `specs/080_exclude_backups_from_literature_index_rebuild/reports/01_post-fix-audit.txt` - new

**Verification**:
- Full extension test suite green: `tests/test-literature-build-index.sh` and
  `tests/test-literature-convert.sh` both exit 0
- `bash -n` and `shellcheck` clean on `literature-build-index.sh`
- Post-rebuild chunk_id-set diff reports zero stale survivors for every `doc_id`
- Zero duplicate-`doc_id` warnings in the rebuild's stderr
- A second rebuild run produces an identical `chunk_id` set (idempotence)
- `literature-search.sh` returns results for a known query against the rebuilt database (the
  index is usable, not merely built)
- No file under `.claude/**` was modified: `git status --short` shows changes only under
  `agent-system/extensions/literature/**` and `specs/**`

---

## Testing & Validation

- [ ] `tests/test-literature-build-index.sh` exits 0 (all six tests A-F pass)
- [ ] The same suite fails when the Phase 2 prune is temporarily reverted (anti-vacuity check)
- [ ] `tests/test-literature-convert.sh` still exits 0 (no collateral regression)
- [ ] `bash -n` and `shellcheck` clean on `literature-build-index.sh`
- [ ] `jq . manifest.json` parses and the new test is registered
- [ ] Live global rebuild with all 14 `.bak` files restored to `chunks.json` produces zero stale
      `chunk_id`s and zero duplicate-`doc_id` warnings
- [ ] Two consecutive global rebuilds produce identical `chunk_id` sets
- [ ] No test run reads from or writes to `~/Projects/Literature/` (only Phase 7's explicit,
      recorded live verification touches the corpus)

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/literature-build-index.sh` (modified: pruned
  traversal, `--strict-duplicates`, exit code 3, database-derived stats)
- `agent-system/extensions/literature/scripts/tests/test-literature-build-index.sh` (new)
- `agent-system/extensions/literature/manifest.json` (modified: test registered in
  `provides.scripts`)
- `agent-system/extensions/literature/context/project/literature/domain/corpus-directory-conventions.md` (new)
- `specs/080_exclude_backups_from_literature_index_rebuild/reports/01_pre-fix-audit.txt` (new)
- `specs/080_exclude_backups_from_literature_index_rebuild/reports/01_bak-rename-mapping.txt` (new)
- `specs/080_exclude_backups_from_literature_index_rebuild/reports/01_post-fix-audit.txt` (new)
- `specs/080_exclude_backups_from_literature_index_rebuild/summaries/01_*-summary.md` (implementation summary)

## Rollback/Contingency

- **Script changes**: single-file, git-tracked. `git revert` of the phase commits restores the
  prior traversal. The commit-per-green-substep mandate keeps each phase independently revertible.
- **Corpus mutation (Phase 7)**: the `.bak` rename mapping is written before any rename, so the
  workaround can be restored file-for-file. The pre-rebuild database backup is a timestamped
  sibling of `.literature.db`; restoring it is a single `mv`.
- **If the prune loses a document**: the Phase 1/Phase 2 before-after `doc_id` comparison catches
  this before any live rebuild. Contingency is to narrow the prune to root-level dot directories
  only (`-mindepth 1 -maxdepth 1 -name '.*' -type d -prune`) and handle the nested `.chunks/`
  case by an explicit path exclusion, at the cost of the generality the predicate was chosen for.
- **If `--strict-duplicates` proves too noisy or too weak in practice**: the default is a
  one-line flip in either direction; the documentation in
  `corpus-directory-conventions.md` is the only other place that must change.
- **The database is ephemeral by design** — it is rebuilt from chunk files on disk, and the build
  uses an atomic `.tmp` + rename. A failed build leaves the previous database in place.
