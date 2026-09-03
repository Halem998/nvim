# Harness: online-ingest failure-mode verification

Scratch, task-local test harness for the online-discovery -> Zotero+PDF -> ingest bridge fixes.
`--dry-run` cannot reach any of the three defects' code paths (it stops before download/write),
so this harness drives the real scripts against stub `zot`, stub `curl` (Unpaywall-only
intercept), and stub `literature-convert.sh`/`literature-chunk.sh`, with `LITERATURE_DIR`
pointed at a fresh scratch directory per run. The real `~/Projects/Literature/` corpus is never
written to (`run-harness.sh` asserts this via a before/after snapshot on every invocation).

## Layout

- `records/` - three synthetic discovery records (arxiv-only, doi-present, in_zotero_no_pdf)
- `bin/` - symlinks to the real scripts under test (`literature-ingest-online.sh`,
  `literature-ingest.sh`, `zotero-write.sh`, etc.) plus purpose-built stubs
  (`literature-convert.sh`, `literature-chunk.sh`, `zotero-read.sh`, `zotero-resolve-pdf.sh`) --
  stubs live alongside the real symlinks so `$SCRIPT_DIR/<sibling>.sh` resolution picks them up.
- `stub-path/` - `zot` and `curl` stubs, prepended to `PATH` by the driver. `curl` passes
  every URL through to the real binary except `api.unpaywall.org` (faked, since Unpaywall
  resolution of the harness's synthetic/fake DOIs is not the thing under test).
- `scratch/` - one fresh `LITERATURE_DIR` per invocation (`run-<random>/Literature`), created
  and left behind for post-run inspection; never the real corpus.
- `run-harness.sh` - driver. `bash run-harness.sh <scenario>`; see its header comment for the
  full scenario list.

## Reproduction commands (verbatim)

```bash
cd specs/109_fix_ingest_online_failure_modes/harness

# Defect (a): arXiv-only record hard-fails zot add --pdf pre-fix
bash run-harness.sh arxiv-only-create-failed   # pre-fix: reproduces CREATE_FAILED(3)
bash run-harness.sh arxiv-only-fixed           # post-fix: expect ONLINE_INGEST_INGESTED
bash run-harness.sh doi-present-unaffected     # post-fix: real DOI path undisturbed

# Defect (b), part 1: staging PDF leak on post-download directive_stop
bash run-harness.sh staging-cleanup-create     # forces item-add failure
bash run-harness.sh staging-cleanup-attach     # forces attach failure (in_zotero_no_pdf path)

# Defect (b), part 2: orphaned sources/<doc_id>/ on literature-ingest.sh's no-cleanup continues
bash run-harness.sh quality-gate-orphan
bash run-harness.sh hard-fail-orphan
bash run-harness.sh no-md-orphan
bash run-harness.sh chunk-fail-orphan

# Defect (c): PIPELINE_FAILED rationale enrichment (message text only)
bash run-harness.sh pipeline-failed-message

# Positive control: cleanup does not fire on a successful ingest
bash run-harness.sh success-control
```

## Confirmed source counts (re-verified against current source, both were Scope Hypotheses)

- `literature-ingest.sh` has **four** no-cleanup `continue` branches in its per-file loop:
  lines 239 (quality-gate reject), 246 (hard convert failure), 259 (conversion reported success
  but no `.md` file found), 279 (chunking failure).
- `literature-ingest-online.sh` has **two** `ONLINE_INGEST_PIPELINE_FAILED` `directive_stop`
  sites: line 717 (resolvable/create-item path) and line 821 (existing-no-pdf/attach path).
