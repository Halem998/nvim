# Baseline Measurements — Phase 1

- **Task**: 77 - Unify the literature global-index schema and end stub-entry invisibility
- **Purpose**: Freeze an execution baseline (Phase 1 of plans/01_unify-global-index-fts-namespace.md)
  before any code or corpus change, per the plan's Scope Hypothesis / rollback requirement that
  execution verification — never a code read — is the evidence standard for every id-touching
  phase.

## Corpus state before any change

```
$ git -C ~/Projects/Literature log --oneline -1
e6ce8bd9 index: add parent entries for baier_katoen_2008 and vardi_wolper_1986

$ git -C ~/Projects/Literature status --short
 D .backups/chunk-regen-2026-07-27/sources/baier_katoen_2008/chunks.json.bak
 D .backups/quarantined-orphaned-chunks-2026-07-27/baier_katoen_2008_dot_chunks/section01/chunks.json.bak
 D .backups/quarantined-orphaned-chunks-2026-07-27/baier_katoen_2008_dot_chunks/section02/chunks.json.bak
 D .backups/quarantined-orphaned-chunks-2026-07-27/baier_katoen_2008_dot_chunks/section03/chunks.json.bak
 D .backups/quarantined-orphaned-chunks-2026-07-27/baier_katoen_2008_dot_chunks/section04/chunks.json.bak
 D .backups/quarantined-orphaned-chunks-2026-07-27/baier_katoen_2008_dot_chunks/section05/chunks.json.bak
 D .backups/quarantined-orphaned-chunks-2026-07-27/baier_katoen_2008_dot_chunks/section06/chunks.json.bak
 D .backups/quarantined-orphaned-chunks-2026-07-27/baier_katoen_2008_dot_chunks/section07/chunks.json.bak
 D .backups/quarantined-orphaned-chunks-2026-07-27/baier_katoen_2008_dot_chunks/section08/chunks.json.bak
 D .backups/quarantined-orphaned-chunks-2026-07-27/baier_katoen_2008_dot_chunks/section09/chunks.json.bak
 D .backups/quarantined-orphaned-chunks-2026-07-27/baier_katoen_2008_dot_chunks/section10/chunks.json.bak
 D .backups/quarantined-orphaned-chunks-2026-07-27/baier_katoen_2008_dot_chunks/section11/chunks.json.bak
 D .backups/quarantined-orphaned-chunks-2026-07-27/baier_katoen_2008_dot_chunks/section12/chunks.json.bak
?? .literature.db.pre-task80-backup-20260824T222614Z
```

**NOT clean.** This is NOT residue from this task's own work — it is uncommitted leftover from a
separate, already-`[COMPLETED]` task (`080_exclude_backups_from_literature_index_rebuild`), whose
implementation renamed 14 `.backups/**/chunks.json.bak` files to `chunks.json` in place (in the
live, non-backup `sources/` tree — hence the deletions showing only under `.backups/`, which is
where the *old, superseded* copies lived) and rebuilt `.literature.db`, but never committed the
corpus-repo change. Confirmed by reading that task's summary
(`specs/080_exclude_backups_from_literature_index_rebuild/summaries/01_exclude-backups-index-rebuild-summary.md`).
This task (77) did not cause this state and does not touch any of the affected paths. Per the
implementer contract's observation duty, this is reported rather than silently folded into or
discarded by this task's work. See the final implementation summary's Observations section for
the recommended resolution.

All measurements below were taken against the corpus **as it stands on disk** (i.e. including
task 80's uncommitted-but-applied fix), since the filesystem/DB content — not git history — is
what every script in this plan actually reads.

## Core counts

```
total entries                                       399
entries with .id == null                               0   (criterion 2 already satisfied)
parent entries (.id set, parent_doc null/empty)      189
FTS distinct chunks_data.doc_id                       204
```

All four match the plan's Overview and Scope Hypothesis exactly. No count correction needed.

## Divergence sets (parent `.id` space vs. FTS `doc_id` space)

```
present in both (parent .id space)                   172
FTS-only  (no parent entry under that id)              32
index-only (parent id, no FTS chunks under that id)    17
```

Matches the plan exactly (172 / 32 / 17).

**Index-only 17** (parent `.id` with no FTS chunks under that literal id — expected to bridge or
be residue):
```
blackburn_2002_book, courcoubetis_1992_memory_efficient, gabbay_2000, gerth_1995_onthefly_ltl,
kupferman_vardi_2001_weak_alternating, piterman_2007_buchi_streett,
schewe_2009_buchi_complementation, schwoon_esparza_2005_onthefly, tarjan_1972_depth_first_search,
thomas_1997_languages_automata, thomas_2003_ch01, thomas_2003_ch03, vardi_1996_automata_ltl,
venema_1993_anti_axioms, venema_1993_since_until, yan_2008_lower_bounds,
zielonka_1998_infinite_games
```

## Path-derived key coverage of FTS doc_ids

```
coverage of FTS doc_ids by parent .id alone            172 / 204
coverage of FTS doc_ids by path-derived dir key         202 / 204
coverage of FTS doc_ids by union(path-derived, .id)     204 / 204
```

Matches the plan's headline claim (172 -> 202 via path derivation alone; the Phase 2 "union of
path-derived key and `.id`" algorithm closes the remaining 2, reaching 204/204).

## Decision C residue re-enumeration

**17 of the 32 FTS-only ids already have a curated parent entry whose path-derived directory key
matches them** (computed by intersecting `fts_only` against the set of path-derived keys of all
189 parent entries):

```
blackburn_2002       <- blackburn_2002_book
courcoubetis_1992    <- courcoubetis_1992_memory_efficient
gerth_1995           <- gerth_1995_onthefly_ltl
girard_1989          <- proofs_and_types                    [duplicate — Decision C residue #2]
kupferman_vardi_2001 <- kupferman_vardi_2001_weak_alternating
piterman_2007        <- piterman_2007_buchi_streett
schewe_2009          <- schewe_2009_buchi_complementation
schwoon_esparza_2005 <- schwoon_esparza_2005_onthefly
tarjan_1972          <- tarjan_1972_depth_first_search
thomas_1997_languages <- thomas_1997_languages_automata
thomas_2003_reactive <- thomas_2003_ch01, thomas_2003_ch03
van_doorn_2015       <- van_doorn_2015_propositional_calculus_coq  [duplicate — residue #2]
vardi_1996           <- vardi_1996_automata_ltl
venema_1993          <- venema_1993_anti_axioms
venema_1993_since    <- venema_1993_since_until
yan_2008             <- yan_2008_lower_bounds
zielonka_1998        <- zielonka_1998_infinite_games
```

**15 FTS-only directories confirmed with NO parent entry at all** (matches the plan's enumerated
list exactly):

```
burgess_1982, burgess_1982b, burgess_1984, derijke_1995, doets_1987, doets_1989, obendrauf_2024,
reynolds_1992, reynolds_1994, thomason_1984, venema_1991, venema_1997, venema_2001,
verbrugge_2004, xu_1988
```

**2 duplicate chunk directories confirmed**: `sources/proofs_and_types/` (duplicating
`sources/girard_1989/`), `sources/van_doorn_2015_propositional_calculus_coq/` (duplicating
`sources/van_doorn_2015/`).

**1 index dir key with no FTS chunks confirmed**: `gabbay_2000` (index-only, `--toc gabbay_2000`
returns `[]` below — conversion rejected per the plan).

Residue is **15 / 2 / 1**, matching the plan's Scope Hypothesis exactly. No count correction
needed; Decision C's enumerated lists in the plan stand as written.

## Probe-set BEFORE output (5 documents)

Full JSON captured verbatim under `reports/baseline-probes/`:
- `baseline_toc_blackburn_2002.json` (13407 bytes, md5 `bdaa0f5edc490bc5ecbff07f3597d99e`)
- `baseline_toc_blackburn_2002_book.json` (3 bytes — `[]`, md5 `58e0494c51d30eb3494f7c9198986bb9`)
- `baseline_toc_burgess_1982.json` (858 bytes, md5 `37d56918163c485e59edccbf02045f5b`)
- `baseline_toc_gabbay_2000.json` (3 bytes — `[]`, md5 `58e0494c51d30eb3494f7c9198986bb9`)
- `baseline_toc_alpern_schneider_1985_defining-liveness.json` (5425 bytes, md5 `0e418516f86d4ea7e3a42383dd9adeeb`, control document, present in both namespaces under the same id)
- `baseline_search_bimodal.json` (11289 bytes — `literature-search.sh --project BimodalLogic "bisimulation"`)

Commands run (source-store script, absolute path, live corpus):
```
literature-search.sh --toc blackburn_2002
literature-search.sh --toc blackburn_2002_book
literature-search.sh --toc burgess_1982
literature-search.sh --toc gabbay_2000
literature-search.sh --toc alpern_schneider_1985_defining-liveness
literature-search.sh --project BimodalLogic "bisimulation"
```

**Baseline defect confirmation** (proves the baseline captures the defect, not a healthy system):
- `--toc blackburn_2002_book` (curated id, no FTS rows under that literal string) -> `[]`
- `--toc gabbay_2000` (index-only, conversion rejected, no chunks) -> `[]`
- `--project BimodalLogic "bisimulation"` returns only `jacobs-coalgebra-intro-draft` and
  `brics-rs-94-7` — zero `blackburn_2002`-family content, even though
  `sources/blackburn_2002/chunks.json` contains 35 real chunks and the parent entry
  `blackburn_2002_book` (id differs from FTS `doc_id` `blackburn_2002`) carries
  `project_tags: ["BimodalLogic"]`. This is breakage (3) from the plan's Research Integration
  section, reproduced live: `get_project_doc_ids()` returns the curated id `blackburn_2002_book`,
  which has zero rows in `chunks_data`, so the `WHERE doc_id IN (...)` filter silently excludes
  every real `blackburn_2002` chunk.

`blackburn_2002` and `burgess_1982` (an FTS-only id with no parent at all) both resolve real
content via `--toc` today — `--toc` addresses FTS directly by doc_id and is unaffected by the
`.id`/`doc_id` divergence; only `.id`-mediated paths (project-filtered search, briefing) are
broken. This is the invariant Phase 2 must preserve: `--toc <id>` behavior for every existing id
is byte-identical after the fix.

## Phase 8 pre-check

`gabbay_2000` confirmed index-only with zero FTS chunks (`--toc gabbay_2000` -> `[]` above),
matching the "conversion rejected" residue item.

## Acceptance criterion 2 (null-id backfill)

Null-`.id` count is 0 (measured above). No backfill work is scheduled anywhere in this plan;
criterion 2 is satisfied by inspection, matching the plan's Non-Goals.
