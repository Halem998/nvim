# Chunk File Conventions

`chunk_NNNN.md` files under `~/Projects/Literature/sources/<dir>/` are **index-only re-splits**,
generated for the FTS5 chunk-search database (see `literature-build-index.sh` / `chunks.json`).
When a directory also carries a canonical document `.md` file, its chunks are near-verbatim
copies of that same content, split at chunk boundaries — not additional material. **This is no
longer guaranteed to be true of every directory**: the ingest pipeline
(`literature-ingest.sh` -> `literature-chunk.sh`) can produce directories whose *only* markdown
is `chunk_NNNN.md` files, with no canonical `.md` present at all. A reader of this file's
original wording ("chunk files are re-splits of that directory's canonical `.md`") should not
assume a canonical `.md` always exists — it does not.

## Conditional exclusion: do not double-count chunks, but do not go blind on chunk-only directories

Any script computing a whole-document metric over `sources/<dir>/*.md` (word counts, fidelity
ratios, content hashes, etc.) MUST apply this conditional rule, not a blanket exclusion:

- **If the directory has a non-chunk `.md`**: exclude `chunk_*.md` files from the computation, or
  the canonical document's content gets summed twice (once via the canonical `.md`, once via its
  own `chunk_*.md` re-splits).
- **If the directory has NO non-chunk `.md` at all** (the chunk-only, pipeline-ingest shape):
  count the `chunk_*.md` files instead. They are the directory's only markdown content; excluding
  them unconditionally makes the directory permanently invisible to the metric (e.g. a word-count
  or fidelity-ratio computation that always reads zero/absent markdown for a directory that in
  fact has real, chunked content on disk).

**Concrete example (double-count)**: a prior fix found that `literature-fidelity-audit.sh`'s
`word_ratio` computation (`md_words / pdf_words`) included `chunk_NNNN.md` files in its `mds`
glob unconditionally, roughly doubling `md_words` for any directory with chunk files present.
This produced spuriously high ratios (e.g. `bacon_2018_broadest-necessity`: reported 1.78, true
~1.0) without changing any document's actual content or classification outcome for the
already-correctly-classified directories — but it made the *reported evidence* dishonest, and for
a hypothetical lower-margin case could have masked a real anomaly.

**Concrete example (blindness, the later-discovered problem with a blanket exclusion)**: the fix
above ("exclude files matching `^chunk_\d+\.md$` unconditionally") was itself later found to be
over-broad: directories like
`agrawal_bonakdarpour_2016_runtime_verification_k_safety_hyperltl/` carry only `chunk_NNNN.md`
files and no canonical `.md`, so an unconditional exclusion left them permanently
`has_md=False` — indistinguishable from a directory with no markdown at all.

**The correct fix is conditional**: prefer the non-chunk `.md` set; fall back to the chunk `.md`
set only when the non-chunk set is empty. This keeps the double-count fix intact for directories
that carry both representations while closing the blindness for chunk-only directories. See
`literature-fidelity-audit.sh`'s `classify_dir()` for the reference implementation (the
`non_chunk_mds` / `chunk_mds` / conditional `mds` assignment).

## Detection

```bash
find ~/Projects/Literature/sources/<dir>/ -iname "chunk_*.md"
```

If this returns anything, check whether a non-chunk `.md` is also present in the same directory:
if so, filter the chunk files out of any whole-document word/line/char count; if not, the chunk
files ARE the whole document and must be counted, not filtered out.

## Related

- `.claude/scripts/literature-fidelity-audit.sh` — the `provenance_fidelity`/`word_ratio`
  detector; applies the conditional exclusion above in `classify_dir()` (see the two concrete
  examples above for the double-count and blindness failure modes this rule prevents).
- `.claude/scripts/literature-build-index.sh` — the consumer that legitimately reads
  `chunk_*.md` files unconditionally (for FTS5 indexing, where per-chunk granularity is the
  point, not a bug).
- `context/project/literature/patterns/provenance-fidelity.md` — documents the full
  `provenance_fidelity` enum and detector signals, including this conditional chunk-counting
  rule in context.
