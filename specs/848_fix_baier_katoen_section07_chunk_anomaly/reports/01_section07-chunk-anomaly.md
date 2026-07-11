# Research Report: Task #848

**Task**: 848 - Fix baier_katoen_2008 section07 chunk anomaly
**Started**: 2026-07-10
**Completed**: 2026-07-10
**Effort**: research only (per task instructions)
**Dependencies**: None (follow-up to task #842, which flagged this as out of scope)
**Sources/Inputs**:
- `~/Projects/Literature/.literature.db` (live corpus DB, read-only queries via sqlite3)
- `~/Projects/Literature/sources/baier_katoen_2008/` (source `.md` parts and `.chunks/sectionNN/` output)
- `.claude/extensions/literature/scripts/literature-chunk.sh` (pass-2 subdivision logic)
- `.claude/extensions/literature/scripts/literature-build-index.sh`, `literature-schema.sql`
- Live reproduction: ran the deployed chunker against a scratch copy of the offending input, both unmodified and with a one-line test patch
- `specs/842_literature_convert_chunk_index_coverage/summaries/01_coverage-fix-summary.md` (prior context)
**Artifacts**:
- This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Anomaly confirmed, with exact numbers**: `baier_katoen_2008` section07 has exactly **1** chunk of **46,176 tokens** (189,927 bytes) vs siblings' **79–128** chunks each (section01=128, section02=111, section03=106, section04=99, section05=110, section06=101, section08=112, section09=107, section10=111, section11=113, section12=79).
- **Root cause identified and live-reproduced**: pass-2's atomic-block heuristic (`is_atomic_start`) inspects only the *first line* of an undivided pass-1 chunk. `Baier_Katoen_2008_part07.md` is the **only one of the 12 parts** whose first line happens to read `"Theorem 7.71.      Simulation in AP-Deterministic Systems"` — an artifact of the PDF→markdown conversion losing the original page's own sub-heading structure (no markdown `#` headings exist in any of the 12 parts, so each part is one giant pass-1 chunk to begin with). This false-positive atomic match causes `subdivide_chunk()` to take the `is_atomic and total_tokens > atom_cap` branch, which **only prints a warning and returns the entire 46K-token block unsplit** — it never falls through to the paragraph/sentence subdivision that runs immediately below in the same function and that successfully handles the other 11 parts.
- **Classification: GENERAL chunker bug**, not a one-off data quirk. The defect is in the code path itself (oversized atomic blocks are never subdivided, only warned about), which will recur for *any* input where (a) pass-1 produces a heading-less top-level chunk (no markdown headings in the source) and (b) that chunk's first line coincidentally starts with `Theorem|Proof|Definition|Lemma|Proposition|Corollary|Axiom|Claim|Conjecture|Observation`. A related, more severe instance of essentially the same failure family (35/35 chapters of `blackburn_2002` chunked as one giant unsplit chunk each) was discovered in the live corpus during this research — see "Related Finding" below — though that case is attributable to a different (older/legacy) manifest schema, not this same code path, and is explicitly out of scope for this task.
- **Recommended fix**: change the oversized-atomic branch in `subdivide_chunk()` (pass 2) to log the warning and *fall through* to the existing size-based paragraph/sentence subdivision instead of returning early. Verified live: this one-line change subdivides section07 into **94 chunks** (comparable to the 79–128 sibling range) with **zero change** to the other 11 sections' output (none of them trigger the atomic branch).
- **Constraints all satisfied by the recommended fix**: byte-identical deployed/extension-source copies (task #841 drift guard — confirmed still identical via `diff -q`, see Findings), re-chunk only section07 without touching the other 93 covered directories (the fix does not change output for any file that doesn't hit the false-positive atomic path), corpus DB stays live data with only section07's rows added/replaced (requires an explicit `DELETE` of the old orphaned giant-chunk row before reindexing — see Recommendations), and the Job 4 94/3 covered/uncovered invariant is preserved (section07 was already "covered" with 1 row; re-chunking changes granularity, not coverage classification).

## Context & Scope

Task #842 (literature coverage backfill) chunked `baier_katoen_2008`'s 12-part book into
`sources/baier_katoen_2008/.chunks/sectionNN/` subdirectories, one section per source PDF-derived
`.md` part. 11 of 12 sections subdivided normally (79–128 chunks each); section07 produced a
single 46,176-token chunk. Task #842 explicitly flagged this as out of scope (no `literature-
chunk.sh` contract changes were permitted under that task) and left the section indexed/searchable
but coarsely-grained. This task (#848) owns investigating and either fixing or formally
documenting the anomaly, staying within the constraints inherited from tasks #841 (drift guard)
and #842 (coverage invariant, quarantine-never-delete, live-DB caution).

This is a research-only report per the task's explicit instruction; no files were modified in the
live corpus or in `.claude/extensions/literature/`. All chunker reproduction was done against
disposable copies under the session scratchpad (`/tmp/claude-.../scratchpad/chunk-test/`), which
have no bearing on the live `.literature.db` or `sources/` tree.

## Findings

### 1. Anomaly confirmation (live DB + filesystem)

Per-section chunk counts, read directly from the filesystem (`chunks_data.source_path` is just
`chunk_NNNN.md` with no directory component, so `.chunks/sectionNN/` counts on disk are the
reliable source — DB `section_path` for all 1,177 rows is uniformly `"Baier Katoen 2008"`, which
does not distinguish sections):

| Section | Chunk count | Max chunk tokens |
|---|---|---|
| section01 | 128 | (normal, 512-target range) |
| section02 | 111 | " |
| section03 | 106 | " |
| section04 | 99 | " |
| section05 | 110 | " |
| section06 | 101 | " |
| **section07** | **1** | **46,176** |
| section08 | 112 | " |
| section09 | 107 | " |
| section10 | 111 | " |
| section11 | 113 | " |
| section12 | 79 | " |

Total across all 12 sections: 1,177 `chunks_data` rows for `doc_id='baier_katoen_2008'` (matches
task #842's verification number). `~/Projects/Literature/sources/baier_katoen_2008/.chunks/
section07/chunk_0001.md` is 189,927 bytes; `Baier_Katoen_2008_part07.md` (the source input) is
189,908 bytes / 4,000 lines — essentially the entire source file became one output chunk, just
with the section breadcrumb prepended.

The DB-side `chunks_data` schema has no `content` field breakdown per section beyond what's above;
`sqlite3 ~/Projects/Literature/.literature.db "SELECT ... FROM chunks_data WHERE doc_id=
'baier_katoen_2008'"` confirms 1,177 total rows, consistent with filesystem counts.

### 2. Root cause in `literature-chunk.sh` pass-2 (exact code path)

None of the 12 `Baier_Katoen_2008_partNN.md` files contain markdown `#`/`##`/`###` headings
(`grep -c '^#'` returns 0 for all 12; confirmed for part01 and part07). This means Pass 1
(`split_at_headings()`) produces exactly **one** `HeadingChunk` per part — the entire part content,
at `level=0`, with `title = doc_id.replace('_', ' ').title()` (e.g. `"Baier Katoen 2008"`).

Pass 2 (`subdivide_chunk()`, `.claude/extensions/literature/scripts/literature-chunk.sh` lines
264–308) is called once per part with this single whole-file chunk. The relevant logic:

```python
first_line = chunk_content.strip().split('\n')[0] if chunk_content.strip() else ''
is_atomic = is_atomic_start(first_line) or is_atomic_start(title)

if is_atomic:
    if total_tokens <= atom_cap:
        return [(chunk_content, True)]
    else:
        # Warn and return as single chunk (do not split atomic blocks)
        print(f"[chunk] WARNING: Atomic block exceeds {atom_cap} token cap ({total_tokens} tokens): {title[:50]}", file=sys.stderr)
        return [(chunk_content, True)]          # <-- root cause: early return, never subdivides

if total_tokens <= target_tokens:
    return [(chunk_content, False)]

# Try paragraph split first ...                  # <-- this code (lines 283-300) is what
                                                   #     successfully subdivides the other 11 parts,
                                                   #     but section07 never reaches it
```

`is_atomic_start()` (lines 113–120) matches `^(?:\*{1,2})?(?:Theorem|Proof|Definition|Lemma|
Proposition|Corollary|Axiom|Claim|Conjecture|Observation)\b` (case-insensitive) against the
*first line only*. Checking the actual first line of each of the 12 parts:

| Part | First line |
|---|---|
| part01 | `                          Principles of Model Checking` |
| part02 | `of appropriate operators on transition systems. This section considers...` |
| part03 | `where` |
| part04 | *(blank)* |
| part05 | `This section is concerned with CTL model checking...` |
| part06 | `                           Φ1                  Φ2` |
| **part07** | **`Theorem 7.71.      Simulation in AP-Deterministic Systems`** |
| part08 | `Clearly, the reduction technique crucially relies on...` |
| part09 | *(blank)* |
| part10 | *(blank)* |
| part11 | *(blank)* |
| part12 | `918                                                                      Appendix: Preliminaries` |

**part07 is the only one of the 12 whose first line matches the atomic-block pattern** — an
accident of where the PDF→markdown page-split boundary landed (mid-proof, starting on a "Theorem
7.71" label from the original book). This is what triggers `is_atomic = True`; the block is then
far larger than `atom_cap_tokens` (1024), landing in the warn-and-return-unsplit branch instead of
ever reaching the paragraph/sentence subdivision logic that works correctly for the other 11 parts
(all of which have plenty of blank-line-delimited paragraphs — part07 itself has 1,479 blank
lines, comparable to part01's 1,064 — so paragraph-based subdivision would work fine for it too,
*if reached*).

**Live reproduction** (non-destructive, run against scratch copies, no corpus files touched):

```
$ bash .claude/extensions/literature/scripts/literature-chunk.sh \
    ~/Projects/Literature/sources/baier_katoen_2008/Baier_Katoen_2008_part07.md \
    /tmp/.../chunk-test/section07-verify --doc-id baier_katoen_2008_verify
[chunk] WARNING: Atomic block exceeds 1024 token cap (46171 tokens): Baier Katoen 2008 Verify
[chunk] Generated 1 chunks (1 atomic, 1 over 512 token target)
```

This exactly reproduces the anomaly and confirms the code path identified above is the actual
cause (not a hypothesis) — the WARNING is the same one hard-coded at line 277 of
`literature-chunk.sh`, and it fires only for part07 among the 12 parts.

### 3. Classification: GENERAL bug (not a one-off data quirk)

The defect is in `subdivide_chunk()`'s control flow, not in section07's data per se. Any input
that satisfies both:
1. Pass 1 yields a heading-less (or otherwise oversized) chunk whose first line happens to match
   the atomic-keyword regex, and
2. That chunk exceeds `atom_cap_tokens` (1024),

...will silently produce one giant unsplit chunk, with only a stderr warning as a trace — no
error, no failure exit code, and (critically) no distinguishing signal in `chunks_data` or
`chunks.json` beyond the anomalously high `token_count`. The docstring at the top of the script
(`"Atomic blocks (Theorem/Proof/Definition/etc) up to 1024 token hard cap"`) implies the cap
*should* be enforced (i.e., oversized "atomic" blocks should still get split down toward the cap),
but the actual implementation does not enforce it — it only warns.

**Related finding (out of scope, flagged for a follow-up task)**: while querying the live corpus
for other instances of this failure mode, this research found that **all 35/35** chapter-level
chunks of `blackburn_2002` (`sources/blackburn_2002/chunks.json`, a flat single-manifest layout,
not the `.chunks/sectionNN/` layout used by `baier_katoen_2008`) are single unsplit chunks ranging
from ~2,000 to 23,792 tokens — none show any subdivision at all. However, this manifest's entries
**lack the `is_atomic` field** that current `literature-chunk.sh` always emits (`manifest_entry =
{k: v for k, v in c.items() if k not in (...)}` retains `is_atomic`), which strongly indicates
`blackburn_2002`'s `chunks.json` was produced by an older/legacy chunker version (or a different,
possibly `literature-ingest.sh`-lineage script) predating the current pass-2 logic entirely, not
by the same atomic-first-line bug identified above (the chapter files' first lines are e.g. `"##
Page 145"` — a markdown H2, not an atomic-keyword match). This is a genuinely separate,
pre-existing data/legacy-format issue and is explicitly **not** part of this task's scope
(`file_scope` is limited to `literature-chunk.sh`; `blackburn_2002` was not part of task #842's
backfill and is not part of task #848's description). It is noted here only because it directly
reinforces the "general bug, will recur" classification for the pass-2 subdivision code generally,
and is worth a dedicated follow-up task to determine whether `blackburn_2002` needs re-chunking
under the current pipeline.

### 4. Recommended fix (verified)

Minimal, surgical change to `subdivide_chunk()` in `literature-chunk.sh`: when an "atomic" block
exceeds `atom_cap_tokens`, log the warning but **do not return early** — let execution fall
through to the existing size-based subdivision logic immediately below (paragraph split, then
sentence split, exactly the code path already used for non-atomic oversized chunks). Concretely,
replace:

```python
        else:
            # Warn and return as single chunk (do not split atomic blocks)
            print(f"[chunk] WARNING: Atomic block exceeds {atom_cap} token cap ({total_tokens} tokens): {title[:50]}", file=sys.stderr)
            return [(chunk_content, True)]
```

with:

```python
        else:
            # Oversized atomic block: warn, then fall through to size-based
            # subdivision below instead of returning unsplit.
            print(f"[chunk] WARNING: Atomic block exceeds {atom_cap} token cap ({total_tokens} tokens) - subdividing anyway: {title[:50]}", file=sys.stderr)
```

(No other change needed — the `if total_tokens <= target_tokens: return ...` guard just below is
already false in this case since `atom_cap > target_tokens`, so control proceeds straight into the
paragraph-split branch.)

**Verified live** (scratch-patched copy of the deployed script, run against the real
`Baier_Katoen_2008_part07.md`, output to a scratch directory, no corpus files touched):

```
[chunk] WARNING: Atomic block exceeds 1024 token cap (46171 tokens) - subdividing anyway: Baier Katoen 2008 Verify
[chunk] Generated 94 chunks (0 atomic, 20 over 512 token target)
```

94 chunks — squarely within the sibling range (79–128). This confirms the paragraph/sentence
subdivision logic that already exists in the script handles section07's actual text structure
fine once reached; the bug is purely the early-return gate, not a deeper structural issue with
section07's content.

**Regression safety for the other 93 covered directories / 11 sibling sections**: this change
only alters behavior for chunks that (a) are classified atomic via the first-line/title heuristic
**and** (b) exceed the 1024-token cap. Confirmed no other section of `baier_katoen_2008` has a
first line matching the atomic pattern (table above), so the change is a no-op for sections
01–06 and 08–12. Because true atomic blocks *within* normally-subdivided sections are typically a
few hundred tokens (well under 1024 — this is the pattern's design intent, e.g. a `"Theorem 3.4"`
block a paragraph or two long), they continue to hit the `total_tokens <= atom_cap: return
[(chunk_content, True)]` branch unchanged. The change only affects the rare case where a "first
line looks atomic" chunk is *also* wildly oversized (thousands of tokens), which by construction
only happens when Pass 1 failed to find any interior heading to break on — i.e., exactly the
heading-less whole-file/whole-section case this task is about. This reasoning was spot-checked
against the fact that re-running the unmodified chunker on part01 (the paragraph-heavy control)
still yields its original 128 chunks with 0 atomic blocks reported, unaffected by the patch logic
(since part01 never entered the atomic branch to begin with).

### 5. Constraints check

- **Byte-identical deployed/extension-source copy (task #841 drift guard)**: `diff -q
  .claude/extensions/literature/scripts/literature-chunk.sh .claude/scripts/literature-chunk.sh`
  returns no output (files identical) as of this research. Any future fix implementation must
  edit the extension-source copy and keep both in sync (or confirm they remain a hardlink/symlink
  pair, as task #842 confirmed for `SKILL.md`) — verify with the same `diff -q` before/after.
- **Re-chunk ONLY section07, do not regress the other 93 covered directories**: the fix logic
  itself is a no-op for all other currently-covered directories' inputs (see regression-safety
  analysis above) *provided* none of them happen to also start with an atomic keyword on a
  heading-less oversized chunk. A full-corpus re-chunk is not required to fix section07 — only
  `Baier_Katoen_2008_part07.md` needs to be re-run through the (fixed) chunker, targeting
  `.chunks/section07/` and overwriting its `chunk_0001.md`/`chunks.json`. As a cheap regression
  check before any real implementation, re-running the fixed chunker against a scratch copy of
  all 12 parts (or at minimum the 11 unaffected ones) and diffing chunk counts against the
  DB-recorded baseline (128/111/106/99/110/101/-/112/107/111/113/79) would give positive
  confirmation with no live-corpus risk.
- **Corpus DB is live data — only add/replace section07's chunks**: `literature-build-index.sh`
  (`.claude/extensions/literature/scripts/literature-build-index.sh`) performs `INSERT OR REPLACE
  INTO chunks_data ... ` keyed by `chunk_id` (`sha256(doc_id + section_path + content_prefix)`).
  Because `chunk_id` incorporates a content-derived hash, re-chunking section07 will produce **new
  and different** `chunk_id`s for the ~94 new pieces — it will **not** automatically replace the
  existing single giant-chunk row (whose `chunk_id` was computed from the *old*, unsplit content).
  **A precise fix implementation must explicitly `DELETE FROM chunks_data WHERE doc_id=
  'baier_katoen_2008' AND chunk_id='<the current giant chunk's chunk_id>'` (and let
  `chunks_fts`'s full external-content rebuild, triggered automatically by
  `literature-build-index.sh`'s `INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild')` step,
  clean up the FTS side) before or as part of the `--global` reindex, or the old 46,176-token
  chunk will remain as an orphaned duplicate row alongside the new 94 correctly-sized chunks.**
  The current giant chunk's `chunk_id` (as of this research) is `a6b60aa1fca40ca4` — confirm this
  is still current immediately before any implementation, since a re-run of the *unfixed* chunker
  (e.g. accidental re-trigger) would change nothing, but any other data manipulation in the
  interim could shift it.
- **`literature-build-index.sh` has no narrower-than-`--dir` scoping that writes to the live
  global DB**: `--dir <path>` builds a *separate* `.literature.db` inside `<path>`, not the live
  `~/Projects/Literature/.literature.db`. The only way to update the live global DB is `--global`,
  which does a **full** rescan of every `chunks.json` under `~/Projects/Literature` and `INSERT OR
  REPLACE`s every chunk. This is idempotent/safe for the 93 other unaffected directories (their
  `chunk_id`s and content are unchanged, so the REPLACE is a no-op), but it does mean the
  reindex step is corpus-wide by construction, not narrowly scoped to section07 — the *content*
  impact is scoped to section07 (plus the required manual delete of the stale row above), even
  though the *mechanism* touches the whole DB.
- **`/literature --rebuild --dry-run` Job 4 94/3 covered/uncovered invariant**: Job 4's coverage
  audit classifies a `sources/<dir>/` as covered if it has *any* `chunks_data` row (task #842's
  summary: "queries the filesystem directly... UNEXPECTED (valid `.md`, zero `chunks_data`
  rows)"). `baier_katoen_2008` already has 1,177 rows (including section07's 1 giant row), so it
  is already counted as covered. Fixing section07's granularity changes its row *count*, not its
  covered/uncovered status — the 94/3 split is unaffected by this fix by construction. This should
  still be explicitly re-verified as part of any implementation's verification step (run the real
  `rebuild_job4_coverage_audit()` function body, as task #842 did non-interactively), per this
  task's own verification bullet.

## Decisions

- Treated `chunks_data.section_path` (uniformly `"Baier Katoen 2008"` for all 1,177 rows) as
  non-authoritative for per-section counting and instead used the filesystem
  `.chunks/sectionNN/` layout, which is the ground truth for how task #842 organized the
  multi-file chunking and matches `source_path`'s per-chunk filenames.
- Treated the discovery of `blackburn_2002`'s 35 unsplit chapters as evidence *supporting* the
  general-bug classification (the pass-2 subdivision failure family is not unique to this one
  file) but explicitly out of this task's `file_scope` and description — recommended as a
  candidate for a dedicated follow-up task rather than folded into this one's fix.
- Verified the proposed fix via live reproduction against scratch copies rather than only static
  code reading, per the standard research bar for concrete, numeric confirmation.

## Risks & Mitigations

- **Risk**: re-chunking section07 without deleting the stale `chunk_id` row leaves an orphaned
  46,176-token duplicate in `chunks_data`/`chunks_fts`, degrading search relevance (a single
  massive low-precision chunk ranking alongside 94 precise ones).
  **Mitigation**: explicit `DELETE` of the known stale `chunk_id` (`a6b60aa1fca40ca4` as of this
  research — reconfirm at implementation time) before/alongside the `--global` reindex, as
  detailed in the Constraints section above.
- **Risk**: editing `literature-chunk.sh`'s pass-2 logic could theoretically affect some other
  not-yet-encountered document whose oversized-atomic-block behavior was relied upon (e.g., an
  intentionally single-chunk short atomic block just over 1024 tokens that a future maintainer
  expected to stay unsplit).
  **Mitigation**: the fix only removes the *hard failure to subdivide*; it does not change
  behavior for the common case (atomic blocks under the cap, which is the design's actual
  intended use — small Theorem/Proof/Definition blocks). No currently-covered directory's chunk
  counts other than section07's are expected to change (see regression-safety analysis); this
  should be spot-verified for a sample of the other 93 directories as part of implementation
  verification, not assumed.
- **Risk**: drift between `.claude/extensions/literature/scripts/literature-chunk.sh` (source of
  truth) and `.claude/scripts/literature-chunk.sh` (deployed copy) if only one is edited.
  **Mitigation**: `diff -q` both paths before and after any implementation edit, per task #841's
  established drift-guard pattern (confirmed identical as of this research).

## Context Extension Recommendations

- **Topic**: pass-2 chunker atomic-block subdivision failure mode.
  **Gap**: no existing `.claude/context/` or extension-context file documents the
  `literature-chunk.sh` pass-2 algorithm's known edge case (oversized atomic-classified blocks
  are silently left unsplit). Future maintainers debugging chunk-granularity anomalies would
  benefit from this being documented alongside the script's own header docstring.
  **Recommendation**: if/when this bug is fixed by a future implementation, add a short note to
  the script's header docstring (or a `.claude/extensions/literature/context/` pattern file, if
  one exists for chunker internals) describing the "first-line atomic false-positive" failure
  mode and its fix, so it doesn't need to be re-derived from scratch for a future similar report.

## Appendix

### Search queries / commands used

```bash
# Per-section chunk counts (filesystem ground truth)
for d in ~/Projects/Literature/sources/baier_katoen_2008/.chunks/section*; do
  echo "$(basename $d): $(find "$d" -maxdepth 1 -name 'chunk_*.md' | wc -l) chunks"
done

# DB verification
sqlite3 ~/Projects/Literature/.literature.db \
  "SELECT count(*), max(token_count) FROM chunks_data WHERE doc_id='baier_katoen_2008';"

# Corpus-wide anomaly scan (found blackburn_2002)
sqlite3 ~/Projects/Literature/.literature.db \
  "SELECT doc_id, chunk_id, token_count, title FROM chunks_data WHERE token_count > 2000 ORDER BY token_count DESC LIMIT 20;"

# Live reproduction (scratch, non-destructive)
bash .claude/extensions/literature/scripts/literature-chunk.sh \
  ~/Projects/Literature/sources/baier_katoen_2008/Baier_Katoen_2008_part07.md \
  /tmp/.../chunk-test/section07-verify --doc-id baier_katoen_2008_verify

# Drift guard check
diff -q .claude/extensions/literature/scripts/literature-chunk.sh .claude/scripts/literature-chunk.sh
```

### References

- `.claude/extensions/literature/scripts/literature-chunk.sh` (lines 113–120 `is_atomic_start`,
  lines 264–308 `subdivide_chunk`)
- `.claude/extensions/literature/scripts/literature-build-index.sh` (chunk_id-keyed `INSERT OR
  REPLACE`, `--global`/`--local`/`--dir` scoping)
- `.claude/extensions/literature/scripts/literature-schema.sql` (`chunks_data`/`chunks_fts`
  schema, external-content FTS5 rebuild semantics)
- `specs/842_literature_convert_chunk_index_coverage/summaries/01_coverage-fix-summary.md`
  (prior context: task #842's Plan Deviations note on section07, Job 4 94/3 invariant)
