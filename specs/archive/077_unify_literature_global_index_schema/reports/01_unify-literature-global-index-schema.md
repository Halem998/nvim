# Research Report: Unify the literature global-index schema and end stub-entry invisibility

**Task**: 77 - Unify the literature global-index schema and end stub-entry invisibility
**Started**: 2026-08-25T00:29:07Z
**Completed**: 2026-08-25T00:33:08Z
**Effort**: 3-6 hours (per task metadata)
**Dependencies**: 32 (redeploy — already done; measurements below are trustworthy)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/literature/scripts/*.sh`, `agent-system/extensions/literature/skills/skill-literature/SKILL.md`
- Live corpus: `~/Projects/Literature/index.json`, `~/Projects/Literature/.literature.db` (measured by execution, not assumed)
- `specs/state.json` (project_number 77, full description incl. four addenda)
- `specs/PATH.md` (Stage 2 "Literature plumbing")
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The invisible-entry population is **already at zero** (`jq '[.entries[]|select(.id==null)]|length'` → `0`; 399 total entries, 73 carry `.doc_id`, all 73 also carry `.id`). Scope (c) (one-shot backfill) is done, out of band, by Literature-repo commits `782ca166` and `a1e74586`. **Do not build a backfill.** Re-verify this count at implementation time — it moves.
- The **writer is still live and unfixed**: `literature-ingest.sh:311-330` still emits the 8-field stub shape (`doc_id`, `title`=bare id literal, `authors: []`, `year: null`, `source_path`, `chunks_dir`, `chunk_count`, `ingested_at` — no `.id`, no `.path`, no `.parent_doc`). The very next ingest recreates the invisible-entry class. This is now the whole of the *invisibility* half of the problem.
- **Confirmed by live measurement**, the fourth namespace (`.literature.db`'s `chunks_data.doc_id`) still disagrees with the index on exactly **49 documents** (32 FTS-only/searchable-but-unbriefed, 17 index-only/briefed-but-unsearchable) — unchanged since the addendum despite the `e6ce8bd9` hand-repair commit. Full lists captured below.
- **New finding, not previously named in the task description**: `literature-search.sh`'s `get_project_doc_ids()` (~line 55-74) builds its allow-list from index.json's `.id` field, then filters `chunks_data.doc_id` (~line 337, `d.doc_id IN (placeholders)`). This is a **second, independent breakage** from the same 4th-namespace mismatch: any of the 49 disagreeing documents is invisible to *project-filtered* search (used by `literature-briefing.sh --global`), regardless of the `--toc`/`--read` breakage already documented. This strengthens the case against any id-renaming approach and for the "keep the FTS id, add a parent entry under it" repair already validated by hand for two documents (commit `e6ce8bd9`, "add parent entries for baier_katoen_2008 and vardi_wolper_1986").
- The reader survey (acceptance criterion 4) is now complete for all scripts named across the task's four addenda plus the absorbed companion task. Verdicts below; most are **not** offenders.
- The parent/child granularity ambiguity (point 3 of the third addendum) is confirmed live: `baier_katoen_2008` has 12 index.json PART-level children vs. 1263 `chunks_data` rows in FTS. `literature-briefing.sh` reports "12 chunk(s)" for a document `--toc` reports as 1263 chunks. This must be decided explicitly for new writes, not inherited silently.
- Recommended scope for the plan: (1) fix the writer to emit the canonical shape keyed by the **same bare id `literature-chunk.sh` already stamped into FTS**, with real metadata where available; (2) decide and document new-ingest chunk granularity (recommend: 1:1 with FTS, i.e. one index.json child per `chunks.json` chunk, not per converted PDF part); (3) decide whether new ingests are placed under `sources/<id>/` (this also switches on `literature-fidelity-audit.sh`'s existing path-prefix targeting for free — a strong argument in favor); (4) add cheap defensive `.id // .doc_id` reader tolerance to `literature-briefing.sh`'s three lookup sites, mirroring the pattern `literature-discover.sh` already uses; (5) add the id-vs-FTS-doc_id schema-conformance check to `/literature --validate` (criterion 5 + new criterion 7); (6) add the ingest-then-brief regression test (criterion 6) plus a case exercising the id/FTS-doc_id agreement check.

## Context & Scope

Task 77 researches, but does not implement, a fix for a writer/reader key mismatch in the
literature extension's global index (`~/Projects/Literature/index.json`) plus three further
namespaces that must be reconciled together: the per-repo sub-index (`specs/literature-index.json`),
the Zotero-key namespace (`specs/zotero-index.json`, `.zotero_key`), and — newly critical per the
task's most recent addendum — the FTS database (`~/Projects/Literature/.literature.db`,
`chunks_data.doc_id`). The task's own addenda record that a naive fix (renaming ids to match the
curated schema) was tried by hand and **broke `--toc`**, so the research explicitly required
tracing all four namespaces together rather than proposing a reader- or writer-only patch.

`file_scope` for this task: `literature-briefing.sh`, `literature-ingest.sh`,
`literature-build-index.sh`, `literature-search.sh`, `literature-fidelity-audit.sh`,
`zotero-attach-chunks.sh`, `skills/skill-literature/SKILL.md`, all under
`agent-system/extensions/literature/` (source store — never the deployed `.claude/` tree).

## Findings

### Codebase Patterns

**The writer (`literature-ingest.sh`, current state, re-verified line numbers)**

- `BASE_DOC_ID` is derived from the source filename (lowercased, punctuation-folded), but the
  *actual* `DOC_ID` used everywhere downstream (line 249: `DOC_ID=$(basename "$MD_FILE" .md)`) is
  whatever `literature-convert.sh` named its output `.md` file — always a **bare**, short form
  (e.g. `vardi_wolper_1986`), never the longer curated form a human later gives it in `index.json`
  (e.g. `vardi_wolper_1986_automata_verification`).
- `literature-chunk.sh` is invoked with `--doc-id "$DOC_ID"` (line 259) and stamps that same bare
  id into every row of `chunks.json` (`literature-chunk.sh:360`, `'doc_id': doc_id`).
  `literature-build-index.sh` then inserts those rows verbatim into `chunks_data.doc_id`
  (`literature-build-index.sh:226,258`). **This is the origin of the FTS-authoritative bare id** —
  it is fixed at chunk time and is never touched by any later index.json curation step.
- Step 4 (lines 285-330) writes the global-index entry: `{"doc_id": DOC_ID, "title": DOC_ID,
  "authors": [], "year": None, "source_path": ..., "chunks_dir": ..., "chunk_count": N,
  "ingested_at": ...}`. No `.id`, `.path`, or `.parent_doc` field is ever written. This is exactly
  the stub shape `literature-briefing.sh` cannot resolve.
- Consequence: **the id `literature-chunk.sh` fixes into FTS at ingest time is always the correct,
  stable key.** Any fix that has the writer (or a later curation pass) invent a *different*, more
  descriptive id for the index.json entry — without also re-keying `chunks_data` — reproduces
  exactly the hand-verified `--toc` breakage recorded in the task's third addendum.

**The reader (`literature-briefing.sh`, current state)**

- Per-repo mode resolves the global-index parent entry via `select(.id == $id and
  (.parent_doc == null or .parent_doc == ""))` (line 175), then a second fallback `select(.id ==
  $id)` without the parent_doc filter (line 181). **Neither branch checks `.doc_id`.** A stub entry
  (id absent) is unconditionally invisible; line 186 emits the `"not found in global index —
  skipping"` warning the task's evidence quotes.
- `get_doc_fidelity()` (line 113) repeats the same `.id == $id` pattern with no `.doc_id`
  fallback — confirmed still true; criterion 3 ("real fidelity value... rather than the fail-open
  default") is not yet addressed for stub-shaped entries.
- Chunk counting (`~204-225`) sums `select(.parent_doc == $id)` children's `token_count`, falling
  back to a single implicit chunk when none are found. This is the mechanism behind the granularity
  finding below: it counts index.json children, never FTS rows.
- Path resolution (`~227-246`) **already prefers `.path`** over any id-derived guess, falling back
  to `$LIT_DIR/sources/$doc_id` only when `.path` is empty or its dirname is `.`. This confirms the
  task's fourth-addendum correction: `literature-briefing.sh` is *not* one of the id-vs-path
  offenders — do not "fix" it there.

**The fourth namespace — measured live, 2026-08-25 (numbers matched the addendum exactly, unchanged)**

```
global-index parent .id (parent_doc null/empty):  189
FTS distinct chunks_data.doc_id:                  204
present in both:                                  172
FTS-only (searchable; no parent entry):            32
index-only (briefed; --toc/--read return nothing): 17
```

Sample FTS-only ids (bare directory-name form, present in `chunks_data` but with no index.json
parent entry under that exact id): `blackburn_2002`, `burgess_1982`, `burgess_1982b`,
`burgess_1984`, `courcoubetis_1992`, `derijke_1995`, `doets_1987`, `doets_1989`, `gerth_1995`,
`girard_1989`.

Sample index-only ids (curated long form in index.json, no matching `chunks_data.doc_id`):
`blackburn_2002_book`, `courcoubetis_1992_memory_efficient`, `gabbay_2000`,
`gerth_1995_onthefly_ltl`, `kupferman_vardi_2001_weak_alternating`,
`piterman_2007_buchi_streett`, `schewe_2009_buchi_complementation`,
`schwoon_esparza_2005_onthefly`, `tarjan_1972_depth_first_search`,
`thomas_1997_languages_automata`.

The pairing is systematic: each index-only id is a curated, more-descriptive rename of its
FTS-only sibling (`blackburn_2002` ↔ `blackburn_2002_book`, `courcoubetis_1992` ↔
`courcoubetis_1992_memory_efficient`). This is direct, live confirmation of the task's hypothesis:
the divergence is (mostly) **the same document renamed at the index layer without a matching
rename in FTS**, not two unrelated writers. `git log` in `~/Projects/Literature` shows the most
recent commit `e6ce8bd9` — *"index: add parent entries for baier_katoen_2008 and
vardi_wolper_1986"* — is the hand-repair the task's third addendum describes: it added parent
entries **under the bare FTS id**, not a rename. That is the working pattern to generalize.

**Second, previously-undocumented breakage from the same mismatch — `literature-search.sh`
project-filtered search**

`get_project_doc_ids()` (lines 55-74) builds its allow-list from `index.json`'s `.id` field
(`.entries[]? | select(project_tags matches) | .id`). `do_search()` then filters
`chunks_data` with `WHERE ... d.doc_id IN (placeholders)` (line ~345) using that allow-list
directly. Because `chunks_data.doc_id` is the bare form and the allow-list is the curated `.id`
form, **any document whose curated id differs from its bare FTS id is silently excluded from
every project-tag-filtered search** — independent of, and in addition to, the already-documented
`--toc` breakage. `literature-briefing.sh --global` mode (the global-corpus search briefing path)
calls `literature-search.sh --project <repo_name>`, so this is not a cold, unused code path — it
is exactly the retrieval path `--lit` global mode exercises. This is strong additional evidence
against any renaming-based fix and for "keep the FTS id, add the index entry under it."

**Parent/child granularity — confirmed live**

`baier_katoen_2008` has exactly 12 index.json children (`parent_doc == "baier_katoen_2008"`,
`Baier_Katoen_2008_partNN.md`, ~229 KB each) vs. **1263** `chunks_data` rows for the same
`doc_id` in FTS. `literature-briefing.sh` therefore reports "12 chunk(s), ~590624 tokens" for a
document `literature-search.sh --toc baier_katoen_2008` reports as 1263 chunks. Both paths
function; the count itself is not comparable across them. A new writer must pick a granularity
(recommend: mirror `chunks.json` 1:1, i.e. one index.json child per FTS chunk row, so the
briefing's count and `--toc`'s count agree by construction for every document ingested going
forward) or carry both counts in explicitly distinct fields. Retrofitting the 12-legacy-books
already on this coarse granularity is **out of scope** — they are already migrated/adjudicated
and not part of the live invisibility problem.

### Reader Survey (acceptance criterion 4 — completed)

| Script | Keys on | Verdict |
|---|---|---|
| `literature-briefing.sh` | `.id` only, 3 sites (114, 175, 181) | **Offender.** No `.doc_id` fallback. Recommend adding `.id // .doc_id` tolerance as defense-in-depth (writer fix is the primary remedy; this is a backstop against any future writer regression or hand-authored entry). |
| `literature-search.sh` (`get_project_doc_ids` → `do_search` filter) | index `.id` → filters `chunks_data.doc_id` | **Offender**, newly identified in this research (see above). Same fix direction as criterion 7: keep index `.id` in the FTS-doc_id namespace so the two lists agree; a reader-side fallback here would require mapping curated ids back to bare ids, which is strictly worse than just not diverging them in the first place. |
| `literature-search.sh` (`--toc`/`--read`/`--doc`, and fidelity-map `sources/` prefix, 4 sites) | `chunks_data.doc_id` directly (native FTS space); fidelity lookup keys on directory name parsed from `.path` prefix `sources/` | **Not an offender** for `--toc`/`--read`/`--doc` — they are supposed to be FTS-native; this is the path that broke when an id was renamed without a matching FTS update, i.e. it is the *symptom detector*, not the bug. The `sources/`-prefix-only fidelity lookup is a **known, already-documented deliberate exclusion** (mirrors `literature-fidelity-audit.sh`'s own header) — leave as is, or extend only if criterion-1's writer places new ingests under `sources/` (see Decisions). |
| `literature-fidelity-audit.sh` | `.path` starting with `sources/<dir>/`; header (lines ~63-67) explicitly documents that legacy `doc_id`/`chunks_dir`-schema entries "live outside `sources/`" and "are never matched or written" | **Known, deliberate exclusion**, already self-documented in the script. Decision needed (see Decisions) rather than a code fix. |
| `zotero-attach-chunks.sh` | `specs/zotero-index.json`'s `zotero_key`, a wholly separate file and namespace; `chunk_dir` field resolved relative to `PROJECT_ROOT` | **Not applicable.** Confirmed: does not touch `~/Projects/Literature/index.json` at all. No id-vs-path issue here; distinct namespace as the task already flagged. |
| `literature-discover.sh` | Tier 1 (line 330): `.id // .doc_id // ""` — **already tolerant of both key shapes**. Tier 2/3: synthesizes its own candidate `doc_id` (DOI slug / `arxiv_*` / `ss_*` / `unknown_*`) for **not-yet-ingested** candidates, written only to its own discovery report — confirmed it never writes into `index.json` | **Not an offender; a positive precedent.** Cite as the pattern to mirror when adding fallback tolerance elsewhere. |
| `literature-normalize-authors.sh` | Operates on `.entries[].authors` uniformly across the whole index; does not key or filter by `id`/`doc_id` at all (confirmed: zero matches for either pattern in the file) | **Not applicable.** Orthogonal schema axis (author-array shape), already scoped out by the task's "vaulted, completed: literature_schema_unification... different axis" note. |
| `zotero-resolve-pdf.sh` | `select(.id == $id)` (line 57) against `index.json`, given a `--doc-id` argument or piped `{"doc_id":...}` | **Reviewed; consistent with the general-purpose `.id` norm**, not a distinct bug. It is exposed to the same disagreement risk as any other `.id`-only consumer for the 49 currently-disagreeing documents (a caller passing the bare FTS id for one of the 17 index-only-with-different-curated-id docs would get `tier: absent`), but this resolves itself once criterion 7 is enforced and no longer diverges the two spaces. No separate code change recommended beyond the general id-agreement fix. |
| `zotero-generate-export.sh` | `.id` referenced only as a Zotero API item URL's trailing path segment (`split("/") | last`) — a completely different "id" (Zotero item key), not `index.json`'s document id | **Not applicable.** False positive in the original grep-based flag; different namespace entirely. |
| `test-lit-pipeline.sh` | Section E fixture uses a single `test_doc_id = "TestPaper2024"` for **both** the global-index `.id` and the sub-index `.doc_id` | **Not an offender, but a coverage gap.** The existing regression suite only ever exercises the matching-key case; it has never caught this defect class. This is exactly what acceptance criterion 6 needs to close (see Decisions). |

### `/literature --validate` gap (acceptance criterion 5) — confirmed and diagnosed

`skill-literature/SKILL.md` Validate Step 1 (`~line 361`) drives its per-entry loop from
`entries=$(jq -r '.entries[] | .path' "$index_file")`. A stub-shaped entry (as
`literature-ingest.sh` writes today) has **no `.path` key at all**, so `jq -r '... | .path'`
yields the literal string `null` for it, and the loop tests `-f "$lit_dir/null"` /
`-d "$lit_dir/null"` — which is false, so the stub is folded into the **stale entries** bucket
under the meaningless label `null (missing)`. This is worse than silent: it actively misreports a
schema-shape defect as a stale-file defect, sending a human toward the wrong fix. Confirms and
sharpens the task's "`--validate` checks the filesystem, not schema shape" finding: the loop must
walk `.entries[]` directly (not only `.path` values) to (a) detect entries lacking `.id`/`.path`
in the first place and (b) — per new criterion 7 — compare the set of parent `.id`s against
`chunks_data.doc_id` (requires invoking `sqlite3` against `.literature.db`, following the same
pattern `literature-search.sh` already uses) and report divergence.

### External Resources

Not applicable — this is a pure codebase/data-shape defect with no external library or API
surface; no web research was needed or performed.

### Recommendations

1. **Writer fix, `literature-ingest.sh` Step 4** — replace the stub write with a canonical-shape
   write: `.id` = the *same* bare `$DOC_ID` already stamped into `chunks.json`/`chunks_data` (do
   **not** invent a longer curated id at ingest time — that is precisely the rename that broke
   `--toc`); `.parent_doc: null`; `.path` pointing at wherever the document actually lands on disk
   (see decision below on `sources/` placement); real `.title`/`.authors`/`.year` pulled from
   Zotero metadata when the source came via `--zotero <key>` (cf. `zotero-read.sh`), with an
   honest, clearly-partial fallback (not a fabricated value) for local-PDF-only ingests without a
   Zotero match. Add one child entry per `literature-chunk.sh`-emitted chunk (1:1 with FTS), each
   carrying that chunk's `token_count`, so `literature-briefing.sh`'s summed count and
   `--toc`'s count agree by construction.
2. **Reader tolerance, `literature-briefing.sh`** — add a `.id // .doc_id` fallback at the three
   `.id ==`-only sites (114, 175/181), mirroring `literature-discover.sh`'s existing pattern. Cheap
   defense-in-depth; does not substitute for item 1.
3. **Fourth-namespace agreement, criterion 7** — for the 32 FTS-only docs, add a parent entry to
   `index.json` under the bare id FTS already holds (the exact operation already validated by hand
   in Literature-repo commit `e6ce8bd9`). For the 17 index-only docs, determine per-document
   whether FTS needs rebuilding under the curated id (re-chunk/re-index) or whether the curated
   entry should instead point at (or be duplicated under) the bare id already in FTS; either
   resolution is acceptable per the task text, but it must be made explicitly and per-document,
   not assumed uniform.
4. **`/literature --validate` schema-conformance check, criterion 5+7** — rewrite the entry-walk
   to iterate `.entries[]` (catching entries lacking `.id`/`.path` directly, not via the `null`
   sentinel-string bug above), and add an explicit id-vs-`chunks_data.doc_id` set-comparison step
   (needs a `sqlite3` call against `.literature.db`, following `literature-search.sh`'s existing
   pattern) that fails loudly on divergence.
5. **Regression test, criterion 6** — extend `test-lit-pipeline.sh` Section E (or a sibling
   section) with a case that ingests (or fixtures the *actual* `literature-ingest.sh` output
   shape, post-fix) a document, runs `literature-briefing-invoke.sh`, and asserts it resolves with
   correct title/authors/year/chunk count; add a second case asserting the new `--validate`
   id-vs-FTS check fails on a deliberately mismatched fixture.

## Decisions

The following must be made explicitly by the plan, not inherited by default — each is a genuine
fork, not a formality:

- **New-ingest filesystem placement**: keep writing to `$LITERATURE_DIR/$DOC_ID/` (current
  behavior, minimal change) vs. move new ingests under `$LITERATURE_DIR/sources/$DOC_ID/`
  (matches the canonical convention the rest of the corpus was already consolidated onto in
  commit `a1e74586`, and — as a direct consequence — makes new entries automatically visible to
  `literature-fidelity-audit.sh`'s existing `sources/<dir>/`-prefix targeting with zero code
  change there). This report recommends the `sources/` placement for that reason, but the
  migration/back-compat implications for any code assuming the old top-level path are not fully
  enumerated here and should be confirmed in planning.
- **New-ingest chunk granularity in index.json**: recommend 1:1 with `chunks.json`/FTS rows (see
  Findings). The alternative (coarser, human-curated parts) is legitimate for hand-curated legacy
  entries but should not be the *default* a script produces unattended.
- **Per-document resolution for the 17 index-only docs**: no single mechanical answer; the plan
  must choose per document (or a documented general rule) between re-indexing under the curated
  id vs. reconciling the index id back to the FTS id.
- **`literature-briefing.sh` `.doc_id` fallback**: worth doing as cheap insurance, but should be
  scoped as secondary to the writer fix — do not let it substitute for fixing the write path,
  since a reader-side patch alone reproduces the "backfill the symptom, not the cause" pattern
  the task's addenda already warn against.

## Risks & Mitigations

- **Risk**: renaming any existing FTS-registered bare id to a curated long form. **Verified
  consequence** (hand-tested by a prior session, reconfirmed by this research's read of
  `literature-search.sh`'s `--toc`/`--read`/`get_project_doc_ids` code paths): breaks `--toc` and
  silently drops the document from project-filtered search. **Mitigation**: never rename; only add
  parent entries under existing FTS ids, per the `e6ce8bd9` precedent.
- **Risk**: fixing only the writer without touching `literature-search.sh`'s
  `get_project_doc_ids()` leaves the newly-discovered project-filtered-search breakage live for
  every one of the 49 currently-disagreeing legacy documents even after the writer no longer
  creates new ones. **Mitigation**: criterion 7's reconciliation (item 3 above) must cover all 49
  existing disagreements, not just the invisible-to-briefing subset, since the search breakage is
  a distinct symptom of the same root cause.
- **Risk**: the `--validate` schema-conformance check reports every one of the 49 known
  disagreements as new failures at once, without a triage mechanism, once implemented before
  reconciliation is complete. **Mitigation**: sequence work so items 1 and 3 land before item 4 is
  turned on as a hard failure, or ship item 4 with a documented, time-boxed known-exceptions list
  referencing this report's measured counts.
- **Risk**: entry counts in this report will have moved by implementation time (the corpus is
  actively repaired from another repo). **Mitigation**: every acceptance criterion should be
  re-measured at implementation start, exactly as this report's own numbers were re-measured
  against the task's addenda before writing it (all matched, confirming the corpus has been
  stable since the last addendum).

## Context Extension Recommendations

- **Topic**: FTS `chunks_data.doc_id` vs. `index.json` `.id` namespace agreement.
- **Gap**: `context/project/literature/domain/literature-index.md` documents the global/per-repo
  index schemas but (as of this research) does not document the FTS namespace or the
  id-must-equal-`chunks_data.doc_id` invariant this task establishes.
- **Recommendation**: once this task lands, add a subsection to that domain doc recording the
  invariant, the "never rename a live FTS id" rule, and the `sources/`-placement /
  fidelity-audit-targeting interaction, so the next person who is tempted to "clean up" an id does
  not rediscover this by breaking `--toc` again.

## Appendix

### Search queries / commands used

- `jq` shape-count query against live `~/Projects/Literature/index.json` (id-only/doc_id-only/both/neither).
- `sqlite3 .literature.db "SELECT COUNT(DISTINCT doc_id) FROM chunks_data;"`
- Python set-comparison of index parent `.id`s vs. `chunks_data.doc_id`s (FTS-only / index-only / both).
- `git log --oneline -8` and `git status --short` in `~/Projects/Literature` (provenance of the out-of-band repair commits).
- Targeted `grep -n` sweeps for `doc_id`, `parent_doc`, `select(\.id ==`, `select(\.doc_id ==`, `sources/`, `zotero_key` across every script named in the task's file_scope and its reader-survey addenda.
- Full reads of `literature-ingest.sh`, `literature-briefing.sh`, `literature-build-index.sh`; targeted reads of `literature-search.sh`, `literature-fidelity-audit.sh` header, `zotero-attach-chunks.sh` header, `skill-literature/SKILL.md` Validate mode.

### References

- `specs/state.json` project_number 77 (full description, four addenda) — primary source of the acceptance criteria and prior evidence this report re-verifies.
- `specs/PATH.md` Stage 2 "Literature plumbing" — cross-task sequencing context (task 78 depends on this task; task 96 also depends on this task).
