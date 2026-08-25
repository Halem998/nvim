# Implementation Summary: Unify the literature global-index schema and end stub-entry invisibility

- **Task**: 77 - Unify the literature global-index schema and end stub-entry invisibility
- **Status**: [PARTIAL]
- **Started**: 2026-08-25T00:49:00Z
- **Completed**: 2026-08-25T03:20:00Z (8 of 10 phases fully complete; 2 phases hold real, well-scoped residual work)
- **Effort**: ~2.5 hours
- **Dependencies**: 32 (redeploy — already satisfied)
- **Artifacts**: plans/01_unify-global-index-fts-namespace.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented the code-side half of a 10-phase plan bridging two independent id namespaces in the
literature extension: `index.json`'s curated `.id` and `.literature.db`'s `chunks_data.doc_id`.
The central decision — bridge by deriving the FTS key from an entry's `sources/<dir>/` path
component, never by renaming a live id — was followed exactly, with `--toc` byte-identical
before/after every id-touching phase. Phases 1-7 and 9 are `[COMPLETED]`; Phase 8 (a destructive
data-reconciliation step in the user's real, separate `~/Projects/Literature/` corpus) is
`[BLOCKED]` and Phase 10's `--validate` hard-failure escalation is `[PARTIAL]`, both deliberately
deferred rather than performed autonomously — see Plan Deviations below.

## What Changed

- `agent-system/extensions/literature/scripts/literature-doc-key.sh` — new. Single sourced anchor
  for the index-entry-to-FTS-key derivation (sourceable function + `--list-keys` CLI).
- `agent-system/extensions/literature/scripts/literature-search.sh` — `get_project_doc_ids()`
  rewired to emit the union of the path-derived key and `.id`, closing the breakage where
  project-filtered search silently excluded every document whose curated `.id` differs from its
  FTS `doc_id`.
- `agent-system/extensions/literature/scripts/literature-briefing.sh` — three `.id`-only lookup
  sites plus title/authors/year/token_count extraction now tolerate `.id // .doc_id`; header
  comment corrected to state the real contract.
- `agent-system/extensions/literature/scripts/literature-ingest.sh` — new ingests land under
  `sources/<id>/` (was top-level); Step 4 rewritten to write a canonical parent entry (`.id ==
  chunks_data.doc_id`, never a curated long form) plus one child entry per `chunks.json` row
  (1:1 granularity); real title/authors/year threaded from Zotero via `zotero-read.sh` on the
  `--zotero <key>` path, with an honest `metadata_status: "unresolved"` marker (never a
  fabricated value) for local-PDF ingests with no Zotero match.
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` — Validate Step 1 no
  longer drives its loop off bare `.path` strings (ending the `null (missing)` misreport for a
  schema-shape defect); added a schema-shape bucket and a WARN-mode namespace-divergence check
  (3 buckets: FTS-only, index-only, id-inconsistent).
- `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` — new Section F: 4 regression
  cases (ingest-then-brief, `--validate` divergence, project-filtered-search bridge,
  schema-shape), each demonstrated red-then-green against a reverted fix.
- `agent-system/extensions/literature/context/project/literature/domain/literature-index.md` —
  new "FTS Namespace and the Never-Rename Invariant" section plus a completed 12-row reader
  survey.
- `agent-system/extensions/literature/scripts/literature-fidelity-audit.sh` — header note updated
  to reflect that new ingests now land inside `sources/`.
- `specs/077_unify_literature_global_index_schema/reports/02_baseline-measurements.md` — Phase 1
  execution baseline (corpus counts, 5-document probe set, divergence enumeration).

## Decisions

- **Parent `token_count` is written as `0`, not the document total, when children exist.**
  Discovered by execution: `literature-briefing.sh`'s chunk-count branch sums children's
  `token_count` AND adds the parent's on top, so a non-zero document-total value there
  double-counts. Matches the corpus's own established precedent (commit `e6ce8bd9`'s two
  hand-added parent entries, which document the identical rationale). Verified: a 6-chunk,
  1338-token fixture reports `~1338 tokens` in the briefing, matching `--toc`'s own sum exactly.
- **Namespace-divergence bucket 3 ("parent entries whose `.id` is neither its own path-derived
  key nor present in FTS") is gated on the dir-key ALSO failing FTS resolution**, not merely
  `.id != dir_key`. The literal plan wording would flag all 17 of Decision C's explicitly
  supported paired entries (curated `.id` differs from FTS `doc_id`, resolved via the path
  bridge) as broken, contradicting Decision C's own statement that this pairing is supported.
  Verified against the live corpus: bucket 3 = 0, matching the plan's stated expectation exactly.

## Plan Deviations

- **Phase 8** (`[BLOCKED]`): reconciling the enumerated corpus residue in
  `~/Projects/Literature/` — adding 15 parent entries, adjudicating 2 duplicate chunk
  directories, resolving `gabbay_2000` — was judged unsafe to perform autonomously. The phase's
  own clean-tree precondition already fails (13 uncommitted lines left by a separate, unrelated,
  already-`[COMPLETED]` task), and the duplicate-directory adjudication requires real content
  judgment on the user's personal, citation-grade corpus with no loud-failure safety net (unlike
  every other phase in this plan). Full reasoning recorded in the plan's Phase 8 `#### Block
  Reason` subsection.
- **Phase 10** (`[PARTIAL]`): the `--validate` WARN-to-FAIL escalation was deferred — escalating
  now would make `/literature --validate` fail against the live corpus immediately, since Phase 8
  did not run (`gabbay_2000` still has 0 FTS chunks). The plan's own Rollback/Contingency section
  treats a non-empty divergence bucket as evidence Phase 8 is unfinished, never as license to
  soften the check. The remaining Phase 10 documentation tasks (FTS-namespace invariant,
  reader-survey record, fidelity-audit header note, source-store-vs-deploy note) are complete.
- **Phase 9 fixture design** (within `[COMPLETED]`): Case 1's fixture parent was made deliberately
  id-less (`.doc_id` only) rather than carrying both `.id`/`.doc_id`, and Case 3 required an
  added decoy document — both changes made the test cases genuinely revert-sensitive to their
  respective fixes rather than merely illustrative (the plan's own red-then-green requirement
  caught both issues during verification; see the Phase 9 progress file for the full account).

## Verification

- Build: N/A (bash/jq extension, no build step)
- Tests: Passed — `test-lit-pipeline.sh --runtime`: 23/23 passed, run from the source-store
  location. All 4 new Section F cases independently demonstrated red-then-green against a
  reverted fix (literature-briefing.sh, literature-search.sh, and SKILL.md each reverted and
  restored in turn; `git status --short` confirmed byte-identical restoration each time).
- Files verified: Yes — every phase's file list confirmed present and correctly shaped by
  execution (fixture ingests, `--toc`, `--project`, `--validate` extraction runs; see each
  phase's progress file for the specific commands and outputs).

## Impacts

- A freshly ingested document (local PDF or `--zotero <key>`) is now resolvable in a briefing
  with real title/authors/year (when Zotero-resolved) and a chunk count that matches `--toc`, for
  every ingest from this point forward.
- Project-filtered search (`literature-search.sh --project`, the path `--global` briefing uses)
  now returns documents whose curated `.id` differs from their FTS `doc_id` — closing a breakage
  that previously excluded 32 FTS-only documents from every project-tag-filtered query.
- `/literature --validate` correctly classifies a schema-shape defect instead of misreporting it
  as a missing file, and surfaces (in WARN mode) exactly one remaining live-corpus divergence
  (`gabbay_2000`) pending Phase 8.
- The corpus data itself (`~/Projects/Literature/`) is untouched by this task; the `--validate`
  hard-failure gate remains at WARN pending a human-reviewed Phase 8.

## Follow-ups

- Complete Phase 8 with human review: commit or discard the separate task's leftover corpus
  changes first, then add the 15 parent entries (low risk, mirrors validated corpus commit
  `e6ce8bd9`), review the two duplicate-directory pairs by hand, and decide `gabbay_2000`.
- Complete Phase 10's escalation once Phase 8 lands: flip the Phase 7 divergence check from WARN
  to a hard failure, carrying forward only the explicitly enumerated known exceptions.
- The companion coverage-marker regression (a deliberately-unresolvable `doc_id` driving the
  lit-coverage marker to report failure rather than `sparse=false`) is a distinct, separately
  tracked defect, noted but out of scope here — see Section F's header comment in
  `test-lit-pipeline.sh`.

## Observations (outside this task's scope, reported per observation duty)

- At Phase 1 start, `~/Projects/Literature/` (a separate git repository) was found with 13
  uncommitted lines of leftover work from a different, already-`[COMPLETED]` task
  (`080_exclude_backups_from_literature_index_rebuild`): 13 deleted `.backups/**/chunks.json.bak`
  files and one untracked `.literature.db.pre-task80-backup-*` snapshot, applied to the working
  tree but never committed in that repo. Not caused by this task; recorded in the Phase 1 baseline
  report and factored into the Phase 8 block decision. Recommended follow-up: commit or discard
  that leftover before attempting Phase 8.
- During this task's own work, unrelated uncommitted changes appeared in this repository's
  working tree (`.claude-extensions.json`, two files under
  `agent-system/extensions/core/context/patterns/`, a deletion under
  `specs/082_wire_deploy_verification_into_deploy_headless/`, and `specs/events.jsonl`) —
  consistent with another concurrently active session in this environment. This task's commits
  were scoped narrowly (via `git-commit-scoped.sh` against only this task's directory and the
  specific files each phase touched) and did not include or disturb any of that foreign work.

## References

- `specs/077_unify_literature_global_index_schema/plans/01_unify-global-index-fts-namespace.md`
- `specs/077_unify_literature_global_index_schema/reports/01_unify-literature-global-index-schema.md`
- `specs/077_unify_literature_global_index_schema/reports/02_baseline-measurements.md`
- `specs/077_unify_literature_global_index_schema/progress/phase-{1..10}-progress.json`
