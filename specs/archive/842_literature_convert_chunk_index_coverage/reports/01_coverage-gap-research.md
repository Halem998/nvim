# Research Report: Task #842

**Task**: 842 - Fix the literature corpus chunk/index coverage gap (convert never chunks/indexes)
**Started**: 2026-07-10T00:00:00Z
**Completed**: 2026-07-10T00:00:00Z
**Effort**: medium (single, well-bounded wiring fix + backfill script + guard note; complicated
  slightly by one multi-section-book edge case and a docid convention subtlety)
**Dependencies**: #840 (added Job 4 audit that surfaced this gap), #841 (reconciled
  `.claude/extensions/literature/` vs deployed `.claude/scripts/` drift — confirmed still
  reconciled, see Findings)
**Sources/Inputs**: `.claude/extensions/literature/scripts/{literature-convert,literature-ingest,
  literature-chunk,literature-build-index}.sh`, `.claude/extensions/literature/scripts/
  literature-schema.sql`, `.claude/extensions/literature/skills/skill-literature/SKILL.md`
  (Mode: Convert / `handle_convert()`, Job 4), live `~/Projects/Literature/.literature.db` and
  `~/Projects/Literature/sources/` (97 directories), `.claude/context/project/literature/patterns/
  chunk-file-conventions.md`
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Re-verified baseline holds exactly**: 25 of 97 `sources/<dir>/` directories have zero
  `chunks_data` rows (re-queried live against `~/Projects/Literature/.literature.db` on
  2026-07-10). Exact list reproduced below — identical to task #840's Job 4 output.
- **The stated root cause is real but imprecisely located — RE-VERIFICATION CORRECTS IT**: the
  gap is *not* that `literature-convert.sh` "stops short" of chunking. `literature-convert.sh` is
  never even called by `/literature --convert`. The user-facing convert path (`handle_convert()`
  in `skills/skill-literature/SKILL.md`, dispatched by `mode=convert`) is a **wholly separate,
  self-contained implementation** using `pdftotext -layout` and inline bash heading-detection —
  entirely independent of the `literature-convert.sh` / `literature-chunk.sh` /
  `literature-build-index.sh` script pipeline used exclusively by `literature-ingest.sh`
  (`--ingest` / Zotero-import paths). `handle_convert()` writes `.md` file(s) and an `index.json`
  entry and then **stops** — it never calls `literature-chunk.sh` or
  `literature-build-index.sh`. This is the actual, corrected root cause. The minimal fix is to
  add two calls inside `handle_convert()`, not to touch `literature-convert.sh` at all.
- **`document_metadata` is a fully orphaned table, not exercised by this bug**: it is declared in
  `literature-schema.sql` but has **zero writers anywhere in the codebase** — not
  `literature-build-index.sh` (which only populates `chunks_data`/`chunks_fts`/
  `chunk_relations`), not `literature-ingest.sh` (which writes a per-doc `metadata.json` *file*
  and updates `index.json`, never the SQL table). It is empty (0 rows) even for the 72
  fully-covered directories. This is a **separate, pre-existing dead-table bug**, not caused by
  and not fixed by closing the convert/chunk gap. Job 4 already documents this correctly and
  deliberately never queries it.
- **Backfill is straightforward for 23 of 25 directories**: each has exactly one existing valid
  `.md` file and no `chunks.json` — re-chunking in place via `literature-chunk.sh <doc>.md
  sources/<dir>/ --doc-id <dir>` followed by a `literature-build-index.sh --global` rebuild is
  sufficient, no re-conversion needed. Two directories (`gabbay_2000`, `negri_von_plato_2001`)
  have **zero** valid `.md` (fully quarantined / rejected) — correctly excluded, nothing to
  backfill, must stay excluded. One directory (`baier_katoen_2008`) is a **multi-section book**
  with 12 separate `.md` files under its directory — the backfill/wiring must aggregate all 12
  under the single `doc_id=baier_katoen_2008` (see Risks).
- **Hazard (a) quarantine exclusion is safe by construction, not by chunker glob strictness**:
  the *directory-level* Job 4 self-check (`grep -qE '\.md\.(bak-|rejected)'` against
  `chunks.json`) is reassuring but the real guarantee is upstream — any wiring fix should invoke
  `literature-chunk.sh` on an **explicit known-good `.md` path** (the one `handle_convert()` just
  wrote), never a directory glob, which sidesteps the quarantine-glob question entirely.
- **Hazard (b) confirmed directly in code**: `literature-ingest.sh` writes chunks to
  `$LITERATURE_DIR/$DOC_ID/` (top-level, **not** `$LITERATURE_DIR/sources/$DOC_ID/`) — this is
  the "legacy `chunks_dir`-schema" entries Job 4 already tracks separately. `handle_convert()`,
  by contrast, already correctly targets `sources/<dir>/` via its `sources_prefix` variable. The
  wiring fix must follow `handle_convert()`'s own path convention (`sources/<dir>/`), not
  replicate `literature-ingest.sh`'s legacy top-level `DOC_DIR` placement.

## Context & Scope

Task #842 was spawned to fix (not just report, which #840's Job 4 already does) the gap where
documents converted via `/literature --convert` are chunked/indexed nowhere, making them silently
invisible to `literature-search.sh`. This report maps the convert vs. ingest code paths exactly,
re-confirms the measured baseline, investigates the empty `document_metadata` table, determines a
safe backfill approach for the 25 existing gaps, and surfaces hazards for the eventual plan.
Constraint: source of truth for implementation is `.claude/extensions/literature/` (not
`.claude/scripts/`, which is a deployed mirror — confirmed byte-identical via `diff`, i.e. #841's
reconciliation still holds as of this research).

## Findings

### Codebase Patterns — the two independent convert-family pipelines

**Pipeline A — script pipeline (`literature-ingest.sh`, used by `/literature --ingest` and the
Zotero import path only)**:

1. `literature-convert.sh <pdf> <tmp_dir>` — PyMuPDF/pymupdf4llm engine tiers with a quality
   gate. Writes `<tmp_dir>/<doc_id>.md` (exit 0) or `<doc_id>.md.rejected` (exit 3, quality-gate
   rejection). **Never calls anything downstream itself** — it is a pure convert-only script by
   design (see its own header comment); the task description's framing of it as "the thing that
   stops short" over-attributes responsibility to this script specifically.
2. `literature-ingest.sh` (lines 200-268 of `literature-ingest.sh`) explicitly chains:
   convert (Step 1) &rarr; `literature-chunk.sh $MD_FILE $DOC_DIR --doc-id $DOC_ID` (Step 2,
   produces `chunks.json` + `chunk_NNNN.md` files) &rarr; writes `metadata.json` (Step 3, a JSON
   *file*, not a DB row) &rarr; updates global `index.json` (Step 4) &rarr; **Step 5**:
   `literature-build-index.sh --global` (rebuilds `chunks_data`/`chunks_fts`/`chunk_relations`
   from every `chunks.json` found under `$LITERATURE_DIR`).
3. **Placement bug (confirmed in code, independent of #842's headline bug)**:
   `literature-ingest.sh` line 179 sets `DOC_DIR="$LITERATURE_DIR/$BASE_DOC_ID"` — i.e. directly
   under the library root, **not** under `sources/`. This is exactly the "legacy `chunks_dir`
   schema" entries that Job 4 (SKILL.md lines 1864-1875) already audits as a separate bucket from
   `sources/<dir>/`. Do not model the wiring fix on this path's placement convention.

**Pipeline B — `handle_convert()` in `skill-literature/SKILL.md` (Mode: Convert, dispatched by
`/literature --convert [FILE]`, also reused by the Zotero-import path's "Import Step 10" via
`PREFILL_*` env vars)**:

- Resolves `lit_dir` = `$LITERATURE_DIR` if set and the directory exists, else falls back to the
  per-repo `specs/literature/` (SKILL.md Step 2, lines 50-65). In this environment
  `LITERATURE_DIR=/home/benjamin/Projects/Literature` and it exists, so `--convert` operates on
  the **same global library** `--ingest` does — the coverage gap is real and user-facing, not a
  per-repo-only edge case.
- Sets `sources_prefix="sources/"` whenever operating on the global library (line 60-64) — so its
  own output convention is already correct: `$lit_dir/sources/<basename_no_ext>[.md |
  /sectionNN_slug.md]`.
- Convert Step 3b/3d: extracts text via `pdftotext -layout` (**not** `literature-convert.sh`'s
  pymupdf4llm/PyMuPDF engine — a second, independent, lower-fidelity extraction implementation),
  detects heading boundaries with inline bash regex, and writes one or more `.md` output files.
- Convert Step 3g: computes `entry_id` and updates `index.json` (the JSON file) with bibliographic
  metadata.
- Convert Step 4: prints a summary. **`literature-chunk.sh` and `literature-build-index.sh` are
  never invoked anywhere in this mode.** Confirmed via `grep -n "literature-convert.sh\|
  literature-chunk.sh" skills/skill-literature/SKILL.md` — zero matches in the entire file (Job 4
  itself only *mentions* `literature-convert.sh` in a comment about the root cause, never
  invokes it).
- Confirmed the deployed `.claude/skills/skill-literature/SKILL.md` is byte-identical to
  `.claude/extensions/literature/skills/skill-literature/SKILL.md` (`diff` returns nothing) — the
  #841 drift-reconciliation guard is holding; implement only in the extension source.

**Minimal wiring change** (for the planner): inside `handle_convert()`'s per-output-file loop
(after Convert Step 3g, i.e. once `output_md` and its `index.json` entry both exist), add a call
to `literature-chunk.sh "$output_md" "$(dirname "$output_md")" --doc-id "<dir-basename>"`, and at
the end of Convert Step 4 (once per invocation, after all files processed) add a call to
`literature-build-index.sh --global` (or `--local` when `lit_dir` resolved to `specs/literature`
instead of `$LITERATURE_DIR` — branch on the same condition Step 2 already uses to set
`sources_prefix`). This reuses the existing chunk/index scripts verbatim — no chunking or FTS5
logic is duplicated.

**doc_id convention subtlety (must be encoded precisely in the plan)**: Job 4 keys coverage on
`chunks_data.doc_id = <sources/dir basename>` (SKILL.md lines 1817-1823, explicitly verified
against the live corpus). For a **single-file** conversion, `entry_id` computed in Step 3g already
equals the directory basename (`basename_no_ext`), so passing `--doc-id "$basename_no_ext"` to
`literature-chunk.sh` is correct and matches `entry_id`. For a **multi-section** conversion (one
document producing several `sectionNN_*.md` files under `sources/<basename_no_ext>/`), Step 3g's
existing `entry_id` is per-section (e.g. `sources_baier_katoen_2008_section01_...`) — that must
**not** be reused as the chunk `--doc-id`; the wiring must instead pass the shared
`--doc-id "$basename_no_ext"` for every section's chunk call so all sections' chunks land under
one `doc_id` in `chunks_data`, matching what Job 4 checks. See Risks for why this matters
concretely (baier_katoen_2008 is exactly this case among the current 25).

### Live Corpus State (re-verified 2026-07-10)

Global library: `~/Projects/Literature` (`LITERATURE_DIR` env var set and directory exists).
`~/Projects/Literature/.literature.db` exists (13.5MB). `sources/` contains 97 directories.

Direct query replicating Job 4's logic (`SELECT count(*) FROM chunks_data WHERE doc_id='<dir>'`
for every `sources/<dir>/`): **72 covered, 25 missing** — identical count and identical list to
task #840's Job 4 output. Exact list of the 25 uncovered directories:

```
baier_katoen_2008        burgess_1982_i            burgess_1982_ii
courcoubetis_1992        gabbay_2000               gerth_1995
girard_1989               hodkinson_2006            kupferman_vardi_2001
libkin_2004_ch3_ch7       negri_von_plato_2001      piterman_2007
rabinovich_2014           schewe_2009               schwoon_esparza_2005
tarjan_1972               thomas_1997               thomas_1997_languages
thomas_2003_reactive      troelstra_schwichtenberg_2000  van_doorn_2015
vardi_1996                vardi_wolper_1986         yan_2008
zielonka_1998
```

Per-directory audit of each (valid `.md` count / quarantine-artifact count / existing
`chunks.json`):

| Directory | valid `.md` | quarantine siblings | `chunks.json` |
|---|---|---|---|
| gabbay_2000 | 0 | 1 | no |
| negri_von_plato_2001 | 0 | 0 (no `.md` at all; report says "do not convert the TOC-only PDF") | no |
| baier_katoen_2008 | **12** (multi-section book) | 0 | no |
| troelstra_schwichtenberg_2000 | 1 | 1 | no |
| rabinovich_2014 | 1 | 1 | no |
| vardi_wolper_1986 | 1 | 1 | no |
| (remaining 19 directories) | 1 each | 0 | no |

None of the 25 have a `chunks.json` — consistent with "never chunked at all," not "chunked but
indexer missed them." This rules out a separate `literature-build-index.sh`-only bug for these
25; the gap is fully explained by the convert-never-chunks root cause. `gabbay_2000` and
`negri_von_plato_2001` correctly have nothing chunkable (fully quarantined / no full-text source)
and must remain excluded from coverage — they are not part of the backfill target set. That
leaves **23 directories** (22 single-file + 1 twelve-file book) as the actual backfill target.

### `document_metadata` investigation

`literature-schema.sql` declares `document_metadata(doc_id, title, authors, year, source_path,
chunks_dir, chunk_count, ingested_at)` (lines 116-125) as a document-level companion to the
chunk-level `chunks_data` table. Grep for `document_metadata` across every script and skill in
`.claude/extensions/literature/scripts/`, `.claude/extensions/literature/skills/`, and
`.claude/scripts/` returns matches **only** in `literature-schema.sql` (the DDL itself) and
`skill-literature/SKILL.md` (Job 4's own commentary that the table is empty and intentionally not
queried). `literature-build-index.sh`'s Python indexer only ever executes `INSERT` statements
against `chunks_data`, `chunks_fts` (via rebuild), and `chunk_relations` — no code path anywhere
inserts into `document_metadata`. Live query confirms `SELECT count(*) FROM document_metadata` =
0, even though 72 of 97 directories are fully covered in `chunks_data` — proving the table's
emptiness is unrelated to the convert/chunk/index gap; it is a **separate, always-empty dead
table** with no writer ever implemented. This is out of this task's stated scope (deliverable 3
only asked to characterize it, not fix it) but should be flagged to the planner as either (a) an
explicit non-goal to note in the plan so it isn't accidentally conflated with the coverage fix, or
(b) a trivial one-line addition to `literature-build-index.sh`'s per-manifest loop (deriving
`title`/`chunk_count`/`ingested_at` from each doc's chunks and/or `metadata.json` file) if the
planner judges it cheap enough to bundle. Recommend treating as **out of scope** for #842's
primary fix and, if desired, spinning off a follow-up task — bundling risks scope creep on what
should be a small, reviewable wiring diff.

### Backfill approach for the 23 target directories

No re-conversion is needed. For each of the 22 single-file directories:

```bash
literature-chunk.sh "$LITERATURE_DIR/sources/<dir>/<dir>.md" \
  "$LITERATURE_DIR/sources/<dir>" --doc-id "<dir>"
```

This is idempotent and safe to run against the existing `.md` in place — `literature-chunk.sh`
only reads the input `.md` and writes `chunk_NNNN.md` + `chunks.json` into the output dir; it does
not touch the original `.md`. For `baier_katoen_2008` (12 section files), run
`literature-chunk.sh` once per section `.md` file but pass the **same** `--doc-id
baier_katoen_2008` each time — however note `literature-chunk.sh` **overwrites** `chunks.json` on
each invocation (it is not additive), so 12 sequential calls against the same output directory
would each clobber the previous section's manifest and chunk files unless the plan accounts for
this (e.g. write each section's chunks to a distinct subdirectory and merge manifests before the
final `literature-build-index.sh` pass, or extend `literature-chunk.sh` with an append mode). This
is the one genuine complication in an otherwise mechanical backfill — flagging it explicitly for
the planner rather than resolving it here, since resolving it changes `literature-chunk.sh`'s
contract and deserves its own plan phase / design decision.

After all backfill chunk calls, a single `literature-build-index.sh --global` rebuild picks up
every directory's `chunks.json` (it recursively finds all `chunks.json` under the target dir) and
regenerates `chunks_data`/`chunks_fts`/`chunk_relations` in one pass — no per-directory rebuild
needed.

### Hazards (for plan constraints)

**(a) Quarantine exclusion.** Confirmed safe by construction as long as the wiring/backfill script
passes an explicit, already-known-good `.md` path to `literature-chunk.sh` (which is what
`handle_convert()` already has in hand right after writing each `output_md`, and what a backfill
script would derive from `find sources/<dir> -maxdepth 1 -name '*.md' -not -name 'chunk_*.md'`
filtered to exclude quarantine-artifact suffixes explicitly) — never chunk via an unfiltered
directory glob. Job 4's own defensive check
(`grep -qE '\.md\.(bak-|rejected)' chunks.json`) is a good *regression* guard to keep, but the
primary guarantee should come from the caller passing an explicit path, not from relying on glob
non-matching alone.

**(b) Placement convention.** Confirmed in code: `literature-ingest.sh` places chunks at
`$LITERATURE_DIR/$DOC_ID/` (no `sources/` prefix) — the "legacy `chunks_dir`-schema" bucket Job 4
already tracks. The wiring fix and backfill script must both target `sources/<dir>/` (matching
`handle_convert()`'s existing `sources_prefix` convention and what Job 4's primary `missing_dirs`
check queries), not replicate `literature-ingest.sh`'s legacy top-level placement.

**(c) `index.json` mutation scope.** Constraint from the task: do not mutate `index.json` entries
beyond adding coverage. The wiring fix only needs to add `literature-chunk.sh` +
`literature-build-index.sh` calls after the existing `index.json` write in Step 3g — it does not
need to (and should not) change any `index.json` field logic.

### Guard opportunity for the future

Job 4 (`rebuild_job4_coverage_audit`, read-only, part of `/literature --rebuild`) already reports
exactly this class of gap. Once the wiring fix lands, Job 4 becomes the natural regression guard:
if `missing_dirs` is ever non-empty again for a *newly converted* (not quarantined) document, that
signals either (1) the wiring fix regressed, or (2) a new convert path was added without the
chunk/index calls. No new script is strictly needed — the planner could optionally add a note to
Job 4's output distinguishing "expected empty" (quarantined docs with no valid `.md`, e.g.
`gabbay_2000`/`negri_von_plato_2001`) from "unexpected empty" (a doc with a valid `.md` but zero
chunks_data rows) by cross-checking `find sources/<dir> -maxdepth 1 -name '*.md'` count > 0 AND
`chunks_data` count == 0, which would make future regressions self-diagnosing rather than
requiring manual triage of the missing-dirs list.

## Decisions

- Treat the convert/chunk/index wiring gap as located in `handle_convert()`
  (`skill-literature/SKILL.md`), not in `literature-convert.sh` — the plan should scope its diff
  accordingly (SKILL.md edit + no changes needed to `literature-convert.sh` itself).
- Treat `document_metadata`'s emptiness as an explicitly out-of-scope, separately-trackable
  finding rather than folding a fix into #842's plan, to keep the wiring fix's diff small and
  reviewable.
- Treat backfill as a one-off script/command run against the 23 target directories (22
  straightforward + 1 requiring a merge-manifest design decision), not as new permanent
  pipeline code — the wiring fix prevents recurrence; backfill only clears the existing 25 (23
  actionable + 2 correctly-excluded).

## Risks & Mitigations

- **Risk**: `baier_katoen_2008`'s 12-file structure could tempt an implementer to run
  `literature-chunk.sh` naively per section, silently leaving only the last section's chunks in
  `chunks_data` (each call overwrites `chunks.json`). **Mitigation**: plan must explicitly call
  out a merge/append strategy or per-section-then-concatenate-manifest step before the final
  `literature-build-index.sh` pass; do not treat this directory as "just like the other 22."
- **Risk**: Reusing `literature-ingest.sh`'s `DOC_DIR` placement pattern by copy-paste would
  reintroduce chunks outside `sources/`, invisible to Job 4's primary check (only caught in the
  "legacy" bucket, and inconsistent with `handle_convert()`'s own established convention).
  **Mitigation**: explicitly anchor the fix to `handle_convert()`'s existing `$lit_dir/
  ${sources_prefix}${basename_no_ext}` path variables, which are already correct.
- **Risk**: Conflating the `document_metadata` dead-table bug with this task's scope could bloat
  the diff and blur review. **Mitigation**: plan should explicitly note it as a non-goal (or a
  clearly separated optional phase), matching Job 4's own precedent of intentionally ignoring
  that table.

## Context Extension Recommendations

- **Topic**: two independent literature convert pipelines (script pipeline vs.
  `handle_convert()`) are not documented anywhere as a single coherent map; this research had to
  reconstruct it from five separate files. **Gap**: no existing context file states "there are
  two convert implementations, here is when each runs and what each does/doesn't wire up."
  **Recommendation**: after #842 lands, add a short pattern doc (e.g.
  `.claude/context/project/literature/patterns/convert-pipeline-map.md`) documenting both paths
  and their chunk/index responsibilities, to prevent a future task from re-discovering this split
  from scratch.

## Appendix

- Search queries / commands used: `find`, `diff` (deployed vs. extension SKILL.md), `grep -rn` for
  `literature-convert.sh`/`literature-chunk.sh`/`document_metadata`/`sources/` across
  `.claude/extensions/literature/scripts/`, `.claude/extensions/literature/skills/`,
  `.claude/scripts/`; direct `sqlite3` queries against `~/Projects/Literature/.literature.db`
  (`SELECT count(*) FROM chunks_data WHERE doc_id=...`, `SELECT count(*) FROM
  document_metadata`); per-directory `find ... -name "*.md"` / quarantine-suffix counts against
  all 25 uncovered `sources/<dir>/` directories.
- Related prior task artifacts: `specs/840_literature_rebuild_subindex_command/` (Job 4 origin),
  `specs/841_reconcile_literature_extension_source_drift/` (source-of-truth reconciliation,
  re-confirmed still holding), `specs/832_reconvert_and_validate_literature_corpus/` (prior
  quarantine/reconversion decisions for `gabbay_2000`/`negri_von_plato_2001` and others),
  `.claude/context/project/literature/patterns/chunk-file-conventions.md` (chunk file placement
  and double-count conventions, relevant to backfill script design).
