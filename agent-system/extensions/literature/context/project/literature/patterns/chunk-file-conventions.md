# Chunk File Conventions

`chunk_NNNN.md` files under `~/Projects/Literature/sources/<dir>/` are **index-only re-splits**
of that directory's canonical document `.md` file(s), generated for the FTS5 chunk-search
database (see `literature-build-index.sh` / `chunks.json`). They are near-verbatim copies of the
same content, split at chunk boundaries — not additional material.

## Do not double-count chunks in whole-document computations

Any script computing a whole-document metric over `sources/<dir>/*.md` (word counts, fidelity
ratios, content hashes, etc.) MUST exclude `chunk_*.md` files from that computation, or the
canonical document's content gets summed twice (once via the canonical `.md`, once via its own
`chunk_*.md` re-splits).

**Concrete example**: `specs/839_fix_fidelity_audit_fail_open/` found that `literature-fidelity-audit.sh`'s `word_ratio`
computation (`md_words / pdf_words`) included `chunk_NNNN.md` files in its `mds` glob, roughly
doubling `md_words` for any directory with chunk files present. This produced spuriously high
ratios (e.g. `bacon_2018_broadest-necessity`: reported 1.78, true ~1.0) without changing any
document's actual content or classification outcome for the already-correctly-classified
directories — but it made the *reported evidence* dishonest, and for a hypothetical
lower-margin case could have masked a real anomaly. The fix: exclude files matching
`^chunk_\d+\.md$` (case-insensitive) from the `mds` glob.

## Detection

```bash
find ~/Projects/Literature/sources/<dir>/ -iname "chunk_*.md"
```

If this returns anything, any whole-document word/line/char count over `*.md` in that directory
must filter these out first.

## Related

- `.claude/scripts/literature-fidelity-audit.sh` — the `provenance_fidelity`/`word_ratio`
  detector; excludes `chunk_*.md` from its `mds` glob (see the double-count fix above).
- `.claude/scripts/literature-build-index.sh` — the consumer that legitimately reads
  `chunk_*.md` files (for FTS5 indexing, where per-chunk granularity is the point, not a bug).
- `specs/839_fix_fidelity_audit_fail_open/` — the task that discovered and fixed the
  double-count defect.
