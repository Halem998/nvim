# Corpus Directory Conventions

## Overview

The global Literature/ repository (`$LITERATURE_DIR`, default `~/Projects/Literature/`) holds
both **live corpus directories** — the documents an index rebuild or search should see — and
**non-corpus directories**: backups, quarantine, staging, and VCS/tooling paths that happen to
live under the same root but must never be treated as live content. This file documents the
predicate any future recursive traversal over the corpus root must use to tell the two apart, the
duplicate-`doc_id` policy that follows once the predicate is applied, and the traversal survey
that confirms which scripts actually need it.

## The "Live Corpus Directory" Predicate

**A path under `$LITERATURE_DIR` is live corpus if and only if no path component below the
traversal's own starting point begins with a dot (`.`).**

This is deliberately a *dot-prefixed-directory-at-any-depth* rule, not a literal `.backups`
exclusion. The corpus root holds several non-corpus dot directories side by side, and a rule
naming only one of them would silently miss the others:

| Directory | Role |
|-----------|------|
| `.backups/` | Manual pre-mutation snapshots and quarantined chunk manifests |
| `.sources-recovered/` | Recovery staging for a prior incident |
| `.online-ingest-staging/` | In-flight staging for the web-discovery ingest path |
| `.git/`, `.claude/`, `.memory/` | VCS and tooling directories, never corpus content |

Any one of these can (and historically did, for `.backups/`) contain an intact `chunks.json` that
is indistinguishable from a live manifest by content alone — the only reliable signal is the
dot-prefixed path component.

### The exact prune expression

```bash
find "$target_dir" -mindepth 1 \( -name '.*' -type d -prune \) -o \( -name 'chunks.json' -print \)
```

This is the exact expression used by `literature-build-index.sh`'s manifest discovery
(`build_index_for_dir`); the script additionally pipes it to `| sort` for deterministic manifest
ordering, which is not part of the prune logic itself. Two properties matter:

1. **`-mindepth 1`**: the prune test is never applied to `$target_dir` itself. A caller who
   explicitly points `--dir` at a dot-named directory (e.g.
   `--dir ~/Projects/Literature/.backups`) still gets it indexed — the exclusion only fires on
   dot-prefixed directories found *below* the traversal's starting point, never on the starting
   point. This matters for deliberate maintenance operations that need to inspect or rebuild a
   quarantine directory directly.
2. **At any depth**: the `-prune` fires on every dot-prefixed directory the traversal descends
   into, not only ones at the corpus root. See "The `.chunks/` legacy case" below for why this
   matters in practice.

### The `.chunks/` legacy case (worked example of a *nested* non-corpus directory)

`sources/thomas_2003_reactive/.chunks/` is a nested dot-prefixed directory three levels below the
corpus root, containing two superseded per-chapter `chunks.json` manifests
(`Thomas_2003_ch01_omega_automata/`, `Thomas_2003_ch03_deterministic_omega/`) that predate the
live top-level `sources/thomas_2003_reactive/chunks.json`. A root-only exclusion
(`-maxdepth 1 -name '.*' -type d -prune`) would miss this case entirely, since `.chunks/` is not
at the corpus root. This is exactly why the predicate is stated as "any depth" rather than
"top-level only" — a nested dot directory is not a hypothetical, it was found live in the corpus.

No script in the extension writes to `.chunks/`; it is legacy residue from an earlier
per-chapter-manifest convention, not an actively maintained directory shape.

## Duplicate-`doc_id` Policy

A `doc_id` can be claimed by more than one manifest — most commonly when a live manifest and a
stale one under a dot-prefixed directory both declare the same `doc_id` (as `thomas_2003_reactive`
did, before the exclusion above removed the dot-prefixed claimant from discovery). The policy for
handling this, independent of the exclusion itself:

**Default: warn loudly, naming the `doc_id` and every claiming manifest path (plus each
manifest's declared chunk count), then build the index anyway (exit 0).**

**Opt-in: `--strict-duplicates` makes the same condition fatal, exiting 3 after reporting every
duplicate** (never failing on the first one found — all duplicates are reported before the exit).

### Reconciliation with `literature-ingest.sh`'s precedent

`literature-ingest.sh` already warns-then-overwrites on a duplicate `doc_id` at the `index.json`
layer. The default behavior above **matches** that precedent rather than diverging from it; the
divergence is confined entirely to the opt-in flag.

### Why fatal is not the default

`skill-literature`'s convert flow invokes `literature-build-index.sh` inside a non-fatal
`|| echo "Warning ... non-fatal"` wrapper. If duplicate detection were fatal by default, a single
ambiguous document would not surface as "one document is ambiguous" — it would surface as *the
entire global index silently not rebuilt*, leaving every document in the corpus stale. That
outcome is strictly worse than indexing the union of the duplicate manifests and reporting the
ambiguity loudly. The `--strict-duplicates` flag exists so a regression test, or a future CI gate,
can assert detection deterministically without accepting that corpus-wide risk as the default for
ordinary operators.

This is a reversible decision: flipping the default to fatal is a one-line change to the flag's
initial value, plus a documentation edit here.

## Traversal Survey

Re-run at the time this document was written, via `grep -n 'find ' scripts/*.sh` and a
`glob`/`os.walk` sweep over `scripts/*.py`:

| Script | Traversal | Depth-bounded? | Needs the predicate? |
|--------|-----------|----------------|----------------------|
| `literature-build-index.sh` | `find` for `chunks.json` | Unbounded (by design — the corpus tree has no fixed depth) | **Yes — the only unguarded recursive traversal, and the fix this document describes** |
| `literature-audit.sh` | `find -maxdepth 2` (PDF and markdown listing) | Yes | No — bounded depth makes a dot-prefixed corpus directory unreachable in practice for its listing use case |
| `literature-ingest.sh` | `find -maxdepth 2` (PDF/DJVU discovery) | Yes | No |
| `literature-ingest-online.sh` | `find -maxdepth 1` (attachment discovery) | Yes | No |
| `literature_combining_detect.py` | `glob.glob()` (single directory, non-recursive) | Yes (glob is inherently one level) | No |
| `literature-search.sh` | None — reads `source_path` values directly, no directory walk | N/A | No |
| `literature-discover.sh` | None found | N/A | No |
| `literature-normalize-authors.sh` | None found | N/A | No |
| `zotero-resolve-pdf.sh` | None found | N/A | No |
| `zotero-generate-export.sh` | None found | N/A | No |
| `test-lit-pipeline.sh` | None found | N/A | No |
| All other scripts under `scripts/` | No `find`/`os.walk`/recursive `glob` present | N/A | No |

**Explicit finding**: no other script needs this predicate today. `literature-build-index.sh` was
the sole unguarded recursive traversal in the extension; every other traversal is either
depth-bounded (`-maxdepth 1` or `-maxdepth 2`, which cannot reach a dot-prefixed directory that
sits below a live document's own top-level directory the way `.chunks/` does) or performs no
directory walk at all.

### `literature-search.sh` inherits corruption only through the database

`literature-search.sh` never walks the corpus directory tree. Its `do_read()` and search paths
read `source_path` values already resolved by a prior index build. It cannot itself index a
backup manifest — but if `.literature.db` was built by an unpruned `literature-build-index.sh`
run, `literature-search.sh` will faithfully surface whatever stale rows that build wrote. Its
correctness on this axis is therefore entirely downstream of the exclusion documented above, not
something `literature-search.sh` itself needs to change.

## Instruction for Future Traversals

Any future script that recursively walks `$LITERATURE_DIR` (or any corpus directory passed via
`--dir`) MUST use the same predicate documented here — the exact `-mindepth 1 \( -name '.*'
-type d -prune \) -o \( ... \)` shape, or an equivalent that excludes dot-prefixed directories at
any depth without pruning an explicitly-named starting point. Do not re-derive a narrower
predicate (e.g. root-level-only, or a literal `.backups` name) — both were considered and
rejected: root-level-only misses the nested `.chunks/` case, and a literal name misses
`.sources-recovered/` and `.online-ingest-staging/`, which hold the same class of non-corpus
content.
