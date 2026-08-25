# Research Report: Task #80

**Task**: 80 - Stop the literature index rebuild from indexing backed-up chunk manifests
**Started**: 2026-08-24T21:51:27Z
**Completed**: 2026-08-24
**Effort**: 1-3 hours
**Dependencies**: Sequenced after task 77 (unify the literature global-index schema and end stub-entry invisibility) — task 77 is `not_started`; this task's scope-item-2 (duplicate-doc_id policy) should be written against task 77's canonical entry shape once it lands, but the traversal exclusion (scope item 1) is independent of task 77 and can proceed regardless.
**Sources/Inputs**: Codebase (`agent-system/extensions/literature/scripts/`), live filesystem state of `~/Projects/Literature/`, live query of `~/Projects/Literature/.literature.db`, `specs/state.json`
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The verified mechanism is confirmed exactly as described: `literature-build-index.sh:91`'s
  `find "$target_dir" -name "chunks.json" | sort` has no `-prune`/`-path`/`-maxdepth` guard and
  will re-admit any `chunks.json` under `.backups/` (or any other dot-prefixed directory) the
  moment an operator forgets the manual `chunks.json.bak` rename workaround.
- **Current corpus state is clean only because of that manual workaround**: `.backups/` presently
  holds 14 `chunks.json.bak` files and zero live `chunks.json` files; the live database (21,951
  chunks, 204 distinct `doc_id`s) shows the correct 99-chunk count for the Schultz/Spivak/
  Vasilakopoulou book and zero `source_path` values matching `%.backups%`. This is a fragile
  invariant an operator is maintaining by hand, not a structural guarantee.
- **Correction to the task's stale-`source_path` framing**: `chunks_data.source_path` is stored as
  a bare filename relative to the manifest's own directory (e.g. `chunk_0001.md`), never an
  absolute or manifest-rooted path. It cannot literally contain `.backups` substring, and the
  schema has **no column at all** recording which manifest/directory a row was built from. A
  substring audit against `source_path` (as acceptance criterion 3 literally reads) will find
  nothing regardless of corruption state — the audit must instead be doc_id/chunk_id-based (see
  Findings below) or the schema must gain a provenance column.
- `document_metadata` (keyed on `doc_id`, holding `chunk_count`) is defined in
  `literature-schema.sql` but is **never populated** by `literature-build-index.sh` — zero rows in
  the live database. This is relevant background for scope direction 4 (visible per-doc reporting)
  but is not itself in the acceptance criteria; flagging so the plan doesn't assume it already
  works.
- The traversal survey in the task description is independently confirmed: `literature-build-
  index.sh:91` is the only unguarded recursive `find -name` traversal in the extension's scripts.
  Every other traversal (`literature-ingest.sh:142`, `literature-audit.sh:104/163/311`,
  `literature-ingest-online.sh:506`) is `-maxdepth 1` or `-maxdepth 2`, and `literature-search.sh`
  performs zero filesystem traversal — it only queries the database `build-index.sh` produces.
- Recommended approach: (1) factor the "live corpus directory" predicate into one shared,
  reusable exclusion (not a bare `.backups` special-case — three other dot-prefixed root
  directories exist today with no `chunks.json` in them yet, and nothing stops one appearing);
  (2) make duplicate-`doc_id`-across-manifests loud (warn-with-both-paths at minimum, evaluate
  fatal) independent of scope item 1, since it also catches non-`.backups` ambiguity that no
  exclusion list can anticipate; (3) add per-`doc_id` chunk-count reporting to `build-index.sh`'s
  existing stats line so a 99-vs-144 mismatch is visible at build time.

## Context & Scope

Researched the verified mechanism, current filesystem/database state, and the codebase-wide
traversal survey needed to ground a plan for the four scope directions and five acceptance
criteria in the task description (full text in `specs/state.json`'s `active_projects[80]`, not
reproduced here as it is already durably recorded there). No code was written — this is a
research-only pass; `literature-build-index.sh` was read, not modified, consistent with the
task's file-scope declaration (`agent-system/extensions/literature/scripts/literature-build-index.sh`)
and the source-store/deploy-boundary rule (all future edits target
`agent-system/extensions/literature/scripts/**`, never `.claude/**`).

## Findings

### Codebase Patterns

**The unguarded traversal** (`literature-build-index.sh:91`):
```bash
mapfile -t manifests < <(find "$target_dir" -name "chunks.json" | sort)
```
`$target_dir` is the Literature root (or `specs/literature/` for `--local`, or a `--dir` override).
No `-prune`, `-path` exclusion, or `-maxdepth`. `find | sort` places `.backups/...` before
non-dotted paths lexicographically, so for any `chunk_id` colliding across both manifests the
later (live) `INSERT OR REPLACE INTO chunks_data` (line 191-196, keyed on `chunk_id` which is
`UNIQUE`) wins — miscount only. But `chunk_id` is `sha256(doc_id+section_path+content_hash)[:16]`
(see schema comment), so a re-chunking that shifts section boundaries produces `chunk_id`s that
exist **only** in the old manifest; those rows have no live counterpart to replace them and
persist permanently, with `content_preview` (line 171-181) read from the **backup** directory's
chunk files (`chunk_file = os.path.join(manifest_dir, source_path)` — `manifest_dir` is
`os.path.dirname(manifest_path)`, so for a backup manifest this correctly resolves inside
`.backups/`, meaning the *content itself* is genuinely stale/superseded even though the DB column
storing it carries no directory marker of that fact).

**Current live-database audit** (acceptance criterion 3, adapted to what's actually auditable):
```
chunks_data total: 21951 rows, 204 distinct doc_id
schultz-spivak-vasilakopoulou-dynamical-systems-sheaves: 99  (matches "should be 99" in task desc)
source_path LIKE '%.backups%': 0 rows (expected — source_path is a bare filename, see below)
document_metadata: 0 rows (table defined, never populated by build-index.sh)
```
The database is currently clean. That cleanliness is contingent entirely on all 14
`chunks.json.bak` renames under `.backups/` having already happened by hand — i.e., the exact
manual workaround acceptance criterion 5 says must become unnecessary. Nothing in the current
pipeline prevents the next backup-writing script (or a manual `cp -r` snapshot) from landing a
live `chunks.json` under `.backups/` again.

**Correction — `source_path` cannot be substring-audited for `.backups`.** Schema comment:
`source_path TEXT DEFAULT '' -- Relative path to chunk .md file on disk`. Observed values are
bare filenames (`chunk_0001.md`, `chunk_0002.md`, ...), not manifest-relative or absolute paths.
The build script never stores `manifest_dir` or `manifest_path` anywhere in the row. So "stale
`source_path` values pointing into `.backups/`" as literally worded in acceptance criterion 3
cannot be detected by inspecting `source_path` — there is no path fragment to grep. A real audit
for pre-fix corruption must instead compare, per `doc_id`, the live manifest's `chunk_id` set
against what's in `chunks_data`; any `chunk_id` present in the DB but absent from the current live
manifest is a stale survivor (of a backup manifest or of any other superseded source). The plan
should either (a) treat the "audit stale `source_path`" criterion as satisfied by this chunk_id-
diff method instead, or (b) add a provenance column (e.g. `source_manifest_dir`) as part of the
fix, which would also make a literal `source_path` audit possible going forward. This is a
scoping decision to hand to the planner, not something to resolve unilaterally in research.

**`document_metadata` is dead code today.** Grepping `literature-build-index.sh` for
`document_metadata` returns nothing — the table defined in `literature-schema.sql` (PK `doc_id`,
column `chunk_count`) is created empty every rebuild and never written to. Scope direction 4 (per-
doc_id chunk-count reporting / diff against prior index) could either populate this dormant table
or just add a `GROUP BY doc_id` count to the stderr stats line already at line 288 — the latter is
far smaller surface area and doesn't require deciding whether to finally wire up
`document_metadata` as a side effect of this task. Recommend the plan scope stats reporting to the
log-line approach and treat `document_metadata` population as out of scope unless the planner
judges otherwise.

**Traversal survey (independently confirmed)**:
| Script | Line | Guard |
|---|---|---|
| `literature-build-index.sh` | 91 | **none** (the bug) |
| `literature-ingest.sh` | 142 | `-maxdepth 2` |
| `literature-audit.sh` | 104 | `-maxdepth 2` |
| `literature-audit.sh` | 163 | scoped to a `$tmp_dir` (conversion scratch dir), not the corpus |
| `literature-audit.sh` | 311 | `-maxdepth 2` |
| `literature-ingest-online.sh` | 506 | `-maxdepth 1`, scoped to a specific `$att_dir` |
| `literature-search.sh` | — | **zero traversal** — queries `.literature.db` only |
| `literature_combining_detect.py` | 263, 269 | `glob.glob` on a single `dirpath`, non-recursive |

No other script performs an unguarded recursive traversal. This confirms the task description's
survey claim and confirms `literature-search.sh`'s exposure is entirely indirect (a corrupted
build propagates into search with no independent check at query time) — there is no traversal
fix needed in `literature-search.sh` itself, only in what `build-index.sh` hands it.

**Existing `.backups/`-writing convention** (relevant for shared-predicate design, scope
direction 1): `literature-repair-combining.sh` writes to
`$LITERATURE_DIR/.backups/combining-repair-{ISO_DATE}/sources/<dir>/<file>` and explicitly
documents "NEVER touches chunk_*.md, chunks.json, or index.json." That script is disciplined
about staying out of `.backups/`'s hazard zone by construction. But the four directories
currently under `.backups/` show **three distinct naming conventions already in production use**
(`chunk-regen-{date}`, `combining-repair-{date}`, `quarantined-orphaned-chunks-{date}`, and an ad
hoc `{doc-slug}_old_{date}` with no script-level convention backing it — this last one looks
operator-created, not script-generated). A bare `-path '*/.backups/*' -prune` currently *would*
cover all four live cases, but two other dot-prefixed root directories exist today with zero
chunk data (`.sources-recovered/`, `.online-ingest-staging/` — the latter is
`literature-ingest-online.sh`'s active staging area for in-flight online ingests, not a backup at
all, and per the task's own point about a shared predicate, a truly generic "what counts as a
live corpus directory" rule should be dot-directory-based (or an explicit corpus-root allowlist)
rather than enumerating `.backups` by name, so it also covers `.sources-recovered`,
`.online-ingest-staging`, and any future dot-prefixed or quarantine-style directory without a
code change.

**Existing duplicate-`doc_id` precedent elsewhere in the extension** (relevant to scope
direction 2): `literature-ingest.sh:181` already has a "Check for re-ingestion: warn if doc_id
already exists" path against `index.json`, and its update step (`literature-ingest.sh:310-311`)
removes the old `index.json` entry for that `doc_id` before writing the new one — i.e. a
**warn-then-overwrite** convention, not fatal. `literature-search.sh` separately treats duplicate
`doc_id` across the local/global DB merge as an intentional, expected case ("local takes
precedence on duplicate doc_id", lines 455/971) — a different scenario (two independent DBs
merged at query time) that should not be conflated with two manifests colliding inside a single
`build_index_for_dir` call. The planner should explicitly reconcile scope direction 2's
fatal-vs-warn choice against the sibling `literature-ingest.sh` convention: a stricter
(fatal-by-default) policy in `build-index.sh` would be a deliberate divergence from that
precedent, justified by the different risk (an *unresolvable* ambiguity between two manifests of
unknown relative freshness, vs. a *known* re-ingestion of the same source) — but it should be a
named, deliberate decision, not an inconsistency the plan trips over unknowingly.

### Recommendations

1. **Shared predicate, not a `.backups` special case.** Implement one small shell
   function/snippet (e.g. `is_live_corpus_path` or an inline `-path` clause list) that `find` in
   `literature-build-index.sh:91` consults, expressed so it naturally excludes any dot-prefixed
   directory under the target root (covers `.backups`, `.sources-recovered`,
   `.online-ingest-staging`, `.memory`, `.claude`, `.git` uniformly) rather than naming `.backups`
   alone. If a future non-dot-prefixed quarantine convention emerges, the predicate is the one
   place to extend. Given only `literature-build-index.sh` is in `file_scope` for this task, keep
   the predicate inline in that script (a small `find ... -path "$target_dir/.*" -prune -o -name
   "chunks.json" -print`-style clause) rather than introducing a new shared library file — that
   would expand file_scope beyond what's declared. If the planner judges a shared library file
   necessary for future scripts to reuse, that should be named as a deliberate file_scope
   expansion, not silently added.
2. **Duplicate-`doc_id` detection should be evaluated as a first-class fix, independent of item
   1** — it catches the same corruption class through any path, including ones no exclusion list
   anticipates (e.g. two independently-conceived directories both under the live corpus that
   happen to describe the same book). Recommend: warn loudly with both manifest paths named at
   minimum (matches the `literature-ingest.sh` warn precedent); the planner should decide whether
   to go further to fatal, and if so, whether an explicit override flag is warranted for
   legitimate multi-manifest-per-doc_id cases (none currently observed, but `--dir` custom targets
   make this plausible).
3. **Traversal survey**: no other script needs the same predicate today — confirmed above. Note
   this as "no other change needed" in the plan rather than skipping the check silently, since the
   acceptance criterion asks it to be *completed*, not assumed.
4. **Stats visibility**: extend the existing stderr summary line (`literature-
   build-index.sh:288`) with a per-`doc_id` chunk count (a `GROUP BY doc_id` query already
   possible against `chunks_data` after the insert loop) so a 99-vs-144 style mismatch is visible
   in the rebuild's own output without needing a separate diff-against-prior-index mechanism. A
   full diff-against-prior-index is heavier (needs the prior DB or a snapshot) and should only be
   pursued if the planner judges the simpler per-doc count insufficient.
5. **Regression test** (acceptance criterion 1): follow the existing `tests/test-literature-
   convert.sh` pattern — a scratch temp directory, never the real `~/Projects/Literature/`
   corpus. Plant a live `chunks.json` + a `.backups/<label>/chunks.json` for the same `doc_id`
   with an overlapping and a non-overlapping `chunk_id`, run `literature-build-index.sh --dir
   <scratch>`, and assert the resulting per-`doc_id` chunk count and the surviving `chunk_id` set
   exactly match the live manifest alone.
6. **Audit acceptance criterion 3**: given the `source_path`-is-bare-filename finding above, plan
   the audit as a chunk_id-set diff (live manifests' `chunk_id`s vs. `chunks_data.chunk_id`s per
   `doc_id`) rather than a literal `source_path LIKE '%.backups%'` query, and run a real clean
   rebuild afterward to confirm the diff goes to zero. State this substitution explicitly in the
   plan so a future reader doesn't think the literal query was tried and passed trivially.

## Decisions

- No implementation decisions made in this research pass — the four scope directions and the
  fatal-vs-warn choice in direction 2 are explicitly left to the planner per the task's own
  "directions, not decisions" framing.
- Adopted as a research-stage decision: audit acceptance criterion 3 will be interpreted via
  chunk_id-set diffing rather than literal `source_path` substring matching, since the latter is
  structurally incapable of finding anything (see Findings). This is a factual correction to how
  the criterion should be *verified*, not a change to what it requires.

## Risks & Mitigations

- **Risk**: A bare `.backups`-only exclusion satisfies today's filesystem snapshot but silently
  under-covers `.sources-recovered/`, `.online-ingest-staging/`, or any future dot-prefixed
  directory. **Mitigation**: dot-directory-general predicate (recommendation 1), not a
  `.backups`-literal string.
- **Risk**: Making duplicate-`doc_id` fatal without an override could break a legitimate
  future `--dir` multi-source workflow. **Mitigation**: planner should scan for any existing
  `--dir` usage pattern that intentionally passes overlapping directories before committing to
  fatal-without-override (none found in this research pass, but the planner has a smaller,
  more targeted grep to run once the exact behavior is chosen).
- **Risk**: Sequencing after task 77 (schema unification) could stall this task if 77 is delayed,
  since 77 also touches `literature-build-index.sh`. **Mitigation**: scope item 1 (traversal
  exclusion) and item 3 (survey) have zero dependency on 77's schema decisions and can land first;
  only scope item 2 (duplicate-`doc_id` policy) genuinely needs 77's canonical entry-shape
  decision. The plan could sequence traversal-fix-first, duplicate-detection-after-77 if 77 is not
  yet ready, rather than blocking the whole task on 77.

## Context Extension Recommendations

- **Topic**: "live corpus directory" predicate / dot-directory exclusion convention
- **Gap**: No existing context file under `context/project/literature/` documents which
  directories under `~/Projects/Literature/` are corpus-live vs. staging/backup/quarantine, or a
  reusable predicate for it. `context/project/literature/domain/literature-index.md` covers index
  *schema*, not traversal safety.
- **Recommendation**: once this task lands, add a short subsection (or new
  `context/project/literature/domain/corpus-directory-conventions.md`) enumerating the known
  non-corpus root directories (`.backups/`, `.sources-recovered/`, `.online-ingest-staging/`) and
  the shared exclusion predicate, so future scripts adding traversal don't have to rediscover this
  research.

## Appendix

- Searches: `grep -n "find "` across `agent-system/extensions/literature/scripts/*.sh`;
  `grep -rn "os.walk|glob.glob|glob("` across `*.py` in the same directory.
- Live queries: `sqlite3 ~/Projects/Literature/.literature.db` — schema dump, total/doc_id counts,
  `source_path LIKE '%.backups%'` check, `document_metadata` row count.
- Filesystem checks: `find ~/Projects/Literature/.backups -name "chunks.json"` (0 results),
  `-name "chunks.json.bak"` (14 results), `find ~/Projects/Literature -maxdepth 1 -type d -name
  ".*"` (six dot-prefixed root directories).
- `specs/state.json`: full task 80 description read via `jq`; task 77 located via title grep to
  confirm the sequencing dependency's current status (`not_started`).
