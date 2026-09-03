# Phase 7 — Corpus re-gate finding

**Purpose**: measure the existing ungated 396-chunk `joyce_1999_foundations-causal-decision-theory`
corpus copy against the FULL quality gate (not just `sentence_boundary_glue_count()`), refreshing
it if the refresh stays mechanical, per the plan's Adjacent-scope decision and the requester's
"backup first; anything beyond a mechanical chunk-and-index replacement stops and hands off"
direction.

## Backup (done first, before any further action)

- `~/Projects/Literature/backups/joyce_1999_foundations-causal-decision-theory_20260902T064713Z/sources-joyce_1999_foundations-causal-decision-theory/`
  — full copy of the 396 `chunk_*.md` files plus `chunks.json`/`metadata.json` if present.
- `~/Projects/Literature/backups/joyce_1999_foundations-causal-decision-theory_20260902T064713Z/index-entries-joyce_1999_foundations-causal-decision-theory.json`
  — all 397 `index.json` entries for this `doc_id` (1 parent + 396 chunk entries), captured
  verbatim before any write.

## Pre-refresh measurement (full gate, not just the glue check)

Ran every check `run_quality_gate()` performs (imported from `literature_quality_gate.py`, plus a
direct `fitz.open()` page-coverage check against the source PDF — the one check that needs the
live `fitz.Document`) against the existing on-disk 396 chunks, joined with `"\n\n"`:

| Check | Result |
|---|---|
| column-interleaving | not flagged |
| sentence-boundary-glue | **2** (< 3 threshold) — both known math-notation strings |
| page-coverage | 117,412 output words / 114,381 source words = 102.6% (within the 40%-250% band) |
| ligature residue | 0 |
| dehyphenation residue | 0 |
| control chars (NUL) | 0 |
| printable ratio | above the 0.85 floor |

**Full gate result: PASS.** The existing on-disk copy already satisfies every check the gate
performs, not merely the one this task was scoped around.

## Refresh decision: mechanical replacement NOT performed

The plan's Task 7.3 calls for replacing the chunk set from "Phase 3's corrected conversion." Per
the requester's guidance after Phase 1's halt, Phases 2-3 performed no re-OCR and produced no
distinct "corrected conversion" — the source PDF was never modified by this task. A literal
chunk-and-index swap was evaluated and NOT performed, for two independent reasons, either
sufficient on its own:

1. **No content-quality benefit.** The existing chunks already pass the full gate, as measured
   above. Regenerating and swapping in near-identical content would not change the pass/fail
   outcome or fix any defect — it would be churn, not correction.
2. **Concurrent, actively-changing tooling.** At measurement time, the ingest pipeline this
   replacement would need to invoke (`literature-ingest.sh`, and `literature-convert.sh` itself)
   was under active, uncommitted modification by a concurrently-running sibling task (later seen
   committed as "task 105 phase 2: distinct needs-OCR bucket in literature-ingest.sh"). Invoking a
   mid-edit ingest pipeline to regenerate this corpus entry is not a deterministic "mechanical"
   step — it risks picking up unrelated in-flight behavior changes (e.g. a new OCR-tier bucketing
   decision) this task has no basis to evaluate or own.

This is the Bound firing as designed: the plan's own text names "building any reusable ingest/OCR
machinery" as out of scope, and depending on a sibling task's WIP ingest tooling to perform a
"mechanical" swap crosses the same line from a different direction. No chunk file, `chunks.json`,
`metadata.json`, or `index.json` entry was written or modified.

## Post-check (unaffected)

- `test-quality-gate-notation.sh`: re-ran after the (no-op) corpus inspection —
  `hott_book_2013`=11, `ahrens_north`=21, all five fixtures pass, unchanged from Phase 6.
- `~/Projects/Literature/index.json` remains valid JSON (`jq .` succeeds) and the entry's
  `chunk_count` (396) already matches the on-disk chunk file count (396) — no update was needed
  since no write occurred.

## Recommendation

If a future task wants this corpus entry's `metadata_status`/`provenance_fidelity` fields
resolved, or wants it formally re-ingested through the (now-changing) gated pipeline for
provenance-cleanliness reasons independent of content quality, that is exactly the kind of
reusable-ingest-machinery-adjacent work the plan assigns to a separate task rather than this one.
This measurement establishes, with evidence, that the corpus is not currently serving
gate-rejected or defective content for this document — the practical quality concern the
Adjacent-scope decision raised is satisfied without a write.
