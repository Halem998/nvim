# Implementation Summary: Unify the literature global-index schema and end stub-entry invisibility

- **Task**: 77 - Unify the literature global-index schema and end stub-entry invisibility
- **Status**: [COMPLETED]
- **Started**: 2026-08-25T00:49:00Z
- **Completed**: 2026-08-25T05:20:00Z (all 10 phases complete)
- **Effort**: ~5 hours
- **Dependencies**: 32 (redeploy — already satisfied)
- **Artifacts**: plans/01_unify-global-index-fts-namespace.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented a 10-phase plan bridging two independent id namespaces in the literature extension:
`index.json`'s curated `.id` and `.literature.db`'s `chunks_data.doc_id`. The central decision —
bridge by deriving the FTS key from an entry's `sources/<dir>/` path component, never by renaming
a live id — was followed exactly, with `--toc` byte-identical before/after every id-touching
phase. Phases 1-7 and 9 landed in an earlier dispatch; this dispatch completed the two phases
that dispatch had left BLOCKED/PARTIAL: Phase 8 reconciled the enumerated residue directly in the
user's real, separate `~/Projects/Literature/` corpus (17 new parent entries, 2 duplicate
directories quarantined, `gabbay_2000` recorded as the sole known exception), and Phase 10
escalated `/literature --validate`'s namespace-divergence check from WARN to a hard failure. Both
were unblocked by explicit user authorization re-verifying the three original block factors
(clean-tree precondition, duplicate-directory content judgment, `gabbay_2000` adjudication) were
resolved or dissolved against the live corpus before acting.

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
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` (Phase 10) — Validate Step
  2b/4 now classify `divergence_index_only` into known-exception vs. unexpected buckets, track a
  `divergence_check_failed` gate (also failing if the check itself must be skipped), and render
  `### Validation FAILED` when any unexpected divergence, schema-shape defect, stale entry, or
  unindexed file survives.
- `agent-system/extensions/literature/manifest.json` (Phase 10) — registered
  `literature-doc-key.sh` in the `scripts` deploy list; it existed since Phase 4/6 but was never
  wired into the deploy manifest, which silently no-op'd the deployed `--validate`
  namespace-divergence check.
- `~/Projects/Literature/index.json` (Phase 8, separate repo) — 17 new parent entries added under
  their bare directory id; 2 stub entries removed (superseded by the new curated entries for the
  duplicate pairs' survivors). Commit `55dc921c`.
- `~/Projects/Literature/sources/.proofs_and_types/`,
  `~/Projects/Literature/sources/.van_doorn_2015_propositional_calculus_coq/` (Phase 8, separate
  repo) — the two duplicate ingest directories, quarantined via `git mv` to a dot-prefixed name
  (reversible, `literature-build-index.sh` prunes dot-prefixed directories by design).

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
- **Phase 8's 17/15/1 split superseded the plan's original 15/2/1 estimate.** Re-measured the
  live corpus before acting, per Phase 8's own Scope Hypothesis instruction to work from current
  numbers rather than the plan's memory: strict `.id`-only comparison found 32 FTS-only ids (15
  already paired with a curated index-only id via the path bridge, needing no action per Decision
  C — renaming/reparenting a live FTS id is the specific operation known to break `--toc` — and
  17 genuinely unpaired, needing a new parent entry) and 17 index-only ids (16 paired + the
  recorded `gabbay_2000` exception). This is not a deviation from the plan — Phase 8's own text
  explicitly authorizes this override.
- **The two duplicate-pair survivors (`girard_1989`, `van_doorn_2015`) are among the 17
  newly-parented ids, not a separate action.** Both had zero index.json coverage before this
  phase (only their duplicate counterpart had a stub entry, pointing at the survivor's PDF via
  `source_path`); the new parent entries were authored from the actual converted text (chapter
  content, PDF filenames) and the FTS chunk/token counts, sequenced after the stub entries'
  removal so nothing was left pointing at a quarantined path.
- **Quarantine, not deletion, for the duplicate directories.** Per explicit user instruction:
  moved to a dot-prefixed name via `git mv` (which `literature-build-index.sh` already prunes by
  design) rather than removing files, keeping the change fully reversible via `git mv` back.

## Plan Deviations

- **Phase 8's 17/15/1 split vs. the plan's original 15/2/1 figures**: not a deviation — see the
  Decisions entry above; the plan's own Scope Hypothesis for Phase 8 instructs exactly this
  override when live measurement disagrees with the plan's memory.
- **Phase 10 additionally fixed a deploy-manifest registration gap** for
  `literature-doc-key.sh` (present in the source store since Phase 4/6, but never added to
  `agent-system/extensions/literature/manifest.json`'s `scripts` list). This is not itemized as a
  Phase 10 task in the plan, but was necessary: the deployed `--validate` divergence check
  silently no-op'd without it (`[ -x "$DOC_KEY_SCRIPT" ]` failed against the deployed tree), which
  would have defeated this phase's own escalation for every user actually running the deployed
  `/literature` command.
- **Phase 9 fixture design** (within `[COMPLETED]` from the prior dispatch): Case 1's fixture
  parent was made deliberately
  id-less (`.doc_id` only) rather than carrying both `.id`/`.doc_id`, and Case 3 required an
  added decoy document — both changes made the test cases genuinely revert-sensitive to their
  respective fixes rather than merely illustrative (the plan's own red-then-green requirement
  caught both issues during verification; see the Phase 9 progress file for the full account).

## Verification

- Build: N/A (bash/jq extension, no build step)
- Tests: Passed — `test-lit-pipeline.sh --runtime`: 23/23 passed, run from both the source-store
  location and (after redeploy) the deployed `.claude/scripts/` location. All 4 Section F cases
  independently demonstrated red-then-green against a reverted fix.
- Files verified: Yes — every phase's file list confirmed present and correctly shaped by
  execution (fixture ingests, `--toc`, `--project`, `--validate` extraction runs; see each
  phase's progress file for the specific commands and outputs).
- Phase 8 (corpus, by execution): `literature-search.sh --toc <id>` for all 17 newly-parented ids
  returned real, non-empty chunk arrays; `literature-briefing-invoke.sh` (deployed) resolved all
  17 in a per-repo sub-index with zero skip warnings; `literature-search.sh --project
  BimodalLogic` returned a newly-parented document; the 5 Phase 1 baseline `--toc` probes stayed
  byte-identical; the reconciled corpus's divergence buckets are FTS-only=0, id-inconsistent=0,
  index-only=1 (`gabbay_2000`, the recorded exception).
- Phase 10 (escalation, by execution): the escalated Validate Step 1/2/2b logic evaluates
  `divergence_check_failed=no` against the live, reconciled corpus (source-store and, after
  redeploy, the deployed copy) and `divergence_check_failed=yes` when re-run standalone against
  the Phase 9 Case 2 fixture (`case2_orphan`, zero FTS coverage) — the hard-failure gate was
  confirmed to actually fire, not just that the raw divergence bucket is populated.

## Impacts

- A freshly ingested document (local PDF or `--zotero <key>`) is now resolvable in a briefing
  with real title/authors/year (when Zotero-resolved) and a chunk count that matches `--toc`, for
  every ingest from this point forward.
- Project-filtered search (`literature-search.sh --project`, the path `--global` briefing uses)
  now returns documents whose curated `.id` differs from their FTS `doc_id` — closing a breakage
  that previously excluded 32 FTS-only documents from every project-tag-filtered query.
- `/literature --validate` correctly classifies a schema-shape defect instead of misreporting it
  as a missing file, and now **fails the command** on any namespace-divergence entry outside the
  recorded `gabbay_2000` exception — the defect class (silent drift between `index.json` and
  `chunks_data.doc_id`) cannot recur unnoticed.
- The live `~/Projects/Literature/` corpus now conforms to the invariant: 17 previously-orphaned
  FTS-only documents (including the two duplicate-pair survivors, `girard_1989` and
  `van_doorn_2015`) are resolvable in a briefing with real metadata; 2 duplicate ingest
  directories are quarantined (reversible) rather than silently duplicating search results and
  citation-grade provenance data.
- The deployed `.claude/` tree previously silently no-op'd the `--validate` divergence check
  entirely (missing `literature-doc-key.sh` in the deploy manifest); this is now fixed, so the
  escalation in Phase 10 actually takes effect for real `/literature --validate` invocations, not
  only for the source-store scripts this task's own verification called directly.

## Follow-ups

- The companion coverage-marker regression (a deliberately-unresolvable `doc_id` driving the
  lit-coverage marker to report failure rather than `sparse=false`) is a distinct, separately
  tracked defect, noted but out of scope here — see Section F's header comment in
  `test-lit-pipeline.sh`.
- None outstanding for Phase 8/10 — the corpus conforms and the escalation is live in both the
  source store and the deployed tree.

## Observations (outside this task's scope, reported per observation duty)

- At Phase 1 start, `~/Projects/Literature/` (a separate git repository) was found with 13
  uncommitted lines of leftover work from a different, already-`[COMPLETED]` task
  (`080_exclude_backups_from_literature_index_rebuild`): 13 deleted `.backups/**/chunks.json.bak`
  files and one untracked `.literature.db.pre-task80-backup-*` snapshot, applied to the working
  tree but never committed in that repo. Not caused by this task. **Resolved before this
  dispatch**: the dispatching session confirmed those changes had been committed out of band
  (corpus HEAD `ee05d80a`, tree clean) before this dispatch began Phase 8.
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
