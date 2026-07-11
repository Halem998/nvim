---
next_project_number: 849
---

# TODO

## Task Order

*Updated 2026-07-11. Generated from state.json dependency graph.*

**Dependency Waves**:
| Wave | Tasks | Blocked by | Topics |
|------|-------|------------|--------|
| 1 | 78,87,821,826,832,837,838 | -- | agent-system, literature, extensions, ... |
| 2 | 822,827 | 821,826 | extensions |

**Grouped by Topic** (indented = depends on parent):

### Agent System

837 [NOT STARTED] — Shared .claude/ infrastructure has diverged across child projects
838 [NOT STARTED] — General skill-lifecycle data-loss bug: the planner-phase postflig

### Literature

832 [PARTIAL] — Reconvert and validate the actionable portion of the ~/Projects/L

### Extensions

821 [RESEARCHED] — Route confirmed email-cleanup decisions (junk vs keep) from the e
  └─ 822 [NOT STARTED] — Implement the email->memory contribution per the #821 design. Add
826 [BLOCKED] — Root-cause and fix the pre-existing Logos (Protonmail Bridge) mai
  └─ 827 [BLOCKED] — The freshness gate shipped in tasks 823-825 is defective: email-c

### Terminal Ui

87 [RESEARCHED] — Investigate why the terminal working directory changes to a proje

### Email Integration

78 [PLANNED] — Fix Gmail SMTP authentication failure when sending emails via Him

## Tasks

### 848. Fix baier katoen section07 chunk anomaly
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [848_fix_baier_katoen_section07_chunk_anomaly/reports/01_section07-chunk-anomaly.md]
- **Plan**: [848_fix_baier_katoen_section07_chunk_anomaly/plans/01_section07-chunk-anomaly.md]
- **Summary**: [848_fix_baier_katoen_section07_chunk_anomaly/summaries/01_section07-chunk-anomaly-summary.md]

**Description**: Investigate and fix (or formally document as acceptable) the `baier_katoen_2008` section07 chunker anomaly flagged by task #842: after the coverage backfill, section07 produced ONE giant chunk versus ~100+ chunks for sibling sections, indicating `literature-chunk.sh`'s pass-2 subdivision did not fire for that file. #842 flagged this out of scope (it was a coverage task, and touching the chunker's contract was a stated non-goal). This task owns it.

RE-VERIFY / RESEARCH FIRST:
1. Confirm the anomaly still exists: query `~/Projects/Literature/.literature.db` `chunks_data` for the `baier_katoen_2008` section07 chunk count vs sibling sections; inspect the giant chunk's size.
2. Read `.claude/extensions/literature/scripts/literature-chunk.sh` pass-2 subdivision logic and determine why it skipped section07 -- likely an input-shape edge case (very long unbroken block, missing delimiter, encoding artifact, or a size threshold that section07 slips past).
3. Decide whether this is a GENERAL chunker bug (would recur for any similarly-shaped input) or a one-off data quirk of this specific file.

REQUIRED WORK: if a general bug, fix the pass-2 subdivision so oversized chunks are subdivided regardless of the triggering input shape, and re-chunk section07 to verify. If a one-off, re-chunk section07 correctly and document why the general path is sound. Either way section07 must end with sibling-comparable chunk granularity.

CONSTRAINTS: SOURCE OF TRUTH is `.claude/extensions/literature/`; keep deployed/extension-source copies of `literature-chunk.sh` byte-identical if edited (task #841 drift guard). Quarantine-never-delete. Do not regress the other 93 covered directories' chunk counts -- re-chunk ONLY section07 (or re-verify all if the chunker logic changes). Corpus DB is live data; only add/replace section07's chunks.

VERIFICATION: `baier_katoen_2008` section07 chunk count is comparable to sibling sections (not 1 giant chunk); no other directory's coverage regressed; if the chunker was edited, deployed==source and `check-extension-docs.sh` still exits 0; `/literature --rebuild --dry-run` Job 4 still reports the same covered/uncovered split (94/3) as after task #842.

---

### 847. Prune dead zotero index scripts
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [847_prune_dead_zotero_index_scripts/reports/01_prune-zotero-index-scripts.md]
- **Plan**: [847_prune_dead_zotero_index_scripts/plans/01_prune-zotero-index-scripts.md]
- **Summary**: [847_prune_dead_zotero_index_scripts/summaries/01_prune-zotero-index-scripts-summary.md]

**Description**: Prune the two confirmed dead-code zotero scripts flagged (defer-and-document, not pruned) by task #844: `.claude/extensions/literature/scripts/zotero-index-add.sh` and `.claude/extensions/literature/scripts/zotero-index-remove.sh`. Task #844's research confirmed `skill-literature/SKILL.md` reimplements the same index add/remove logic inline via `jq`, so these two scripts have no live callers and are pure dead code. #844 intentionally left them in place (defer-and-document) rather than pruning inline; this task removes them cleanly.

RE-VERIFY FIRST: grep the deployed `.claude/` (skills, commands, agents, other scripts) and the extension source for any reference to `zotero-index-add` / `zotero-index-remove` to CONFIRM zero live callers before removing. If any live reference is found, STOP and report -- do not remove.

REQUIRED WORK: apply the QUARANTINE-NEVER-DELETE posture -- move the two scripts to a quarantine location (e.g. rename with a `.removed-<UTC>` suffix or move to a deprecated/ dir per repo convention) rather than hard-deleting. Remove them from the literature `manifest.json` `provides.scripts` if listed. Update the 'Deployment Status' / inactive-artifacts note in `.claude/extensions/literature/README.md` that #844 added, moving these two from 'deferred' to 'removed'. Leave the other deferred zotero scripts (`zotero-read/write/setup/chunk/attach-chunks.sh`) untouched -- they depend on the external `zot` CLI and are a separate decision.

CONSTRAINTS: SOURCE OF TRUTH is `.claude/extensions/literature/`. Quarantine-never-delete. Do not regress `check-extension-docs.sh` (exit 0) -- removing a script AND its manifest entry together keeps the drift guard happy; removing only one side would trip it. Do not touch the deployed `.claude/scripts/` copies unless the scripts were also deployed (research says they were extension-source-only -- confirm).

VERIFICATION: no live reference to the two scripts remains; manifest and README updated consistently; `check-extension-docs.sh` still exits 0 with literature PASS; the quarantined files still exist (not hard-deleted).

---

### 846. Add literature entry to extensions json
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [846_add_literature_entry_to_extensions_json/reports/01_literature-extensions-entry.md]
- **Plan**: [846_add_literature_entry_to_extensions_json/plans/01_literature-extensions-entry.md]

**Description**: Add the missing `literature` entry to `.claude/extensions.json` so the literature extension is properly tracked/installed like `core`, `nix`, `nvim`, and `memory`. Surfaced by task #844, which DELIBERATELY did NOT fabricate the entry because `.claude/extensions.json` is loader-owned and getting its schema wrong could break extension loading -- so it documented the gap instead. This task does it correctly.

RE-VERIFY / RESEARCH FIRST (do not guess the schema):
1. Read `.claude/extensions.json` and study the EXACT shape of the existing entries (core/nix/nvim/memory) -- field names, version, enabled flags, script/hook lists, whatever they carry.
2. Read the extension loader (`lua/neotex/plugins/ai/shared/extensions/loader.lua` and its `init.lua`) to understand how entries in `extensions.json` are consumed -- what fields it reads, whether a missing entry means 'not loaded' or is merely cosmetic tracking, and what a malformed entry would do.
3. Determine whether the literature extension is currently being loaded DESPITE having no entry (its scripts are clearly deployed and working), which tells you whether this entry is load-bearing or bookkeeping.

REQUIRED WORK: add a correctly-formed `literature` entry matching the established schema and the loader's expectations. Do not change loader behavior; do not enable/disable other extensions.

CONSTRAINTS: `.claude/extensions.json` is loader-owned -- match existing entries exactly; a malformed entry is worse than a missing one. Do not regress `check-extension-docs.sh` (currently exit 0). If adding the entry changes what gets loaded/synced, verify no literature script gets clobbered (task #841 drift guard must still pass).

VERIFICATION: `.claude/extensions.json` parses; the literature entry matches sibling entries' schema; the loader accepts it (dry-run/load without error); `check-extension-docs.sh` still exits 0; no unexpected re-sync/clobber of deployed literature scripts.

---

### 845. Implement routing hard precedence in router
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [845_implement_routing_hard_precedence_in_router/reports/01_routing-hard-precedence.md]
- **Plan**: [845_implement_routing_hard_precedence_in_router/plans/01_routing-hard-precedence.md]

**Description**: Implement the `--hard`/`routing_hard` 5-step precedence in `command-route-skill.sh` so it matches what CLAUDE.md documents and what `test-command-route-skill.sh` tests against. Surfaced by task #843's research: `command-route-skill.sh` does NOT currently implement `routing_hard` dispatch at all, yet CLAUDE.md's 'Routing Mechanism' section documents a 5-step precedence (non-core exact -> non-core compound-key -> core exact -> core compound-key -> `-hard` append fallback with an on-disk SKILL.md existence gate), and a test file asserts that behavior.

THIS IS THE MOST SUBSTANTIVE of the cleanup follow-ups -- it is a real doc/code/test divergence, not cosmetic. RE-VERIFY before acting (the #843 finding was a side-observation, not the task's focus):
1. Read `.claude/scripts/command-route-skill.sh` and its extension-source copy; confirm whether/how it resolves an `effort_flag`/`--hard` 4th argument and whether it consults `routing_hard` in any manifest.
2. Read `.claude/scripts/test-command-route-skill.sh` (and any extension-source copy) to see exactly what precedence behavior is asserted -- the tests are the executable spec.
3. Read the 'Routing Mechanism' 5-step precedence block in CLAUDE.md (and its merge-source EXTENSION.md) as the documented contract.

REQUIRED WORK: reconcile the three (code, test, docs). Determine the source of truth -- most likely the documented+tested contract is correct and the SCRIPT is behind. Implement the 5-step precedence in `command-route-skill.sh` so the existing tests pass. If instead the tests/docs are wrong, correct them with justification. Whatever the direction, all three must agree at the end.

CONSTRAINTS: SOURCE OF TRUTH is `.claude/extensions/*/`. If `command-route-skill.sh` exists in both deployed `.claude/scripts/` and an extension source, keep them byte-identical (the task #841 drift guard polices this). Do not regress the currently-green `check-extension-docs.sh` (exit 0, 19/19 PASS as of task #843). Preserve the on-disk SKILL.md existence safety gate that Step 5 requires.

VERIFICATION: `bash .claude/scripts/test-command-route-skill.sh` passes; a manual trace of each of the 5 precedence steps produces the documented winner; deployed and extension-source copies byte-identical; `check-extension-docs.sh` still exits 0.

---

### 844. Finish or defer zotero cite install
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: Task 842
- **Research**: [844_finish_or_defer_zotero_cite_install/reports/01_install-status-research.md]
- **Plan**: [844_finish_or_defer_zotero_cite_install/plans/01_install-plan.md]
- **Summary**: [844_finish_or_defer_zotero_cite_install/summaries/01_install-summary.md]

**Description**: Finish or formally defer the incomplete literature-extension install surfaced (out of scope) by task #841's drift audit. Ten scripts and one command exist ONLY in the extension source `.claude/extensions/literature/` and were never deployed to `.claude/scripts/` / `.claude/commands/`, and the extension is not fully wired into `.claude/extensions.json`.

MEASURED (verified 2026-07-10, re-verify): extension-source-only scripts: `zotero-attach-chunks.sh`, `zotero-chunk.sh`, `zotero-index-add.sh`, `zotero-index-remove.sh`, `zotero-read.sh`, `zotero-search.sh`, `zotero-setup.sh`, `zotero-write.sh`, `cite-extract.sh`, `test-lit-pipeline.sh`. Command-source-only: `.claude/extensions/literature/commands/cite.md` (deployed `.claude/commands/cite.md` is ABSENT). The `/cite` command is documented in CLAUDE.md but its command file was never deployed.

DECISION REQUIRED (this is the crux -- do not blindly deploy): for the zotero suite and `cite`, determine whether they are (a) intended-to-be-active features whose install was left unfinished, or (b) work-in-progress / experimental that should stay inactive. Base this on git history, whether they are referenced by any live skill/command, and whether the `/cite` command in CLAUDE.md is meant to be usable now.
- If (a) ACTIVE: register them in `provides.scripts` (some already added by #841/follow-up -- avoid duplicates), ensure the deploy/sync mechanism (loader.lua `copy_scripts`) propagates them, deploy `cite.md`, and confirm `.claude/extensions.json` tracks the literature extension correctly.
- If (b) INACTIVE: add a clear note (in the extension README/manifest) documenting them as intentionally not-yet-deployed so they stop reading as accidental drift, and ensure the #841 drift guard does not false-fail on them (it already skips entries whose deployed copy is absent -- verify).

CONSTRAINTS:
- SOURCE OF TRUTH is `.claude/extensions/literature/`.
- `test-lit-pipeline.sh` is almost certainly test-harness-only and should NOT be deployed as a runtime script regardless -- treat separately.
- Quarantine-never-delete.

VERIFICATION: either every intended script/command is deployed AND `check-extension-docs.sh` literature section still PASSes with no drift-guard false-failures, OR the inactive ones are documented and the extension state is internally consistent (no dangling references to undeployed scripts from live skills/commands).

---

### 843. Fix core lean doclint failures
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [843_fix_core_lean_doclint_failures/reports/01_doclint-diagnosis.md]
- **Plan**: [843_fix_core_lean_doclint_failures/plans/01_doclint-fix-plan.md]
- **Summary**: [843_fix_core_lean_doclint_failures/summaries/01_doclint-fix-summary.md]

**Description**: Restore the `core` and `lean` sections of `.claude/scripts/check-extension-docs.sh` to PASS. These are pre-existing doc-lint failures (they predate tasks #840/#841 -- verified) but they keep the overall check exiting non-zero, which blunts the value of the literature drift guard that task #841 added INSIDE this same script: a future literature regression would hide in an already-red run.

MEASURED FAILURES (verified 2026-07-10, re-verify -- run `bash .claude/scripts/check-extension-docs.sh`):
- core: `script referenced in docs/skills/agents but NOT in provides.scripts` for `task-lock.sh`, `orchestrator-postflight.sh`, and `literature-briefing-invoke.sh`.
- lean: `routing_hard target declared but not deployed (and extension not installed)` for `skill-lean-research-hard` and `skill-lean-implementation-hard`.

REQUIRED WORK: For each failure determine the correct resolution (register the script in the owning extension's `provides.scripts` if it legitimately belongs there; fix/remove a stale reference if the doc reference is wrong; or correct the lean `routing_hard` declaration / mark the lean extension appropriately if it is intentionally not installed). Do NOT paper over a real gap by deleting a valid reference -- diagnose each. Note `literature-briefing-invoke.sh` is attributed to core here; confirm which extension truly owns it (task #841's follow-up already registered it under literature -- ensure no double-ownership conflict).

CONSTRAINTS:
- SOURCE OF TRUTH is `.claude/extensions/*/` manifests -- edit there.
- Do not alter runtime behavior of any script; this is manifest/doc hygiene only.

VERIFICATION: `bash .claude/scripts/check-extension-docs.sh` exits 0 with all sections (core, lean, literature, and every other) PASS. The literature drift guard added by #841 still passes.

---

### 842. Literature convert chunk index coverage
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [842_literature_convert_chunk_index_coverage/reports/01_coverage-gap-research.md]
- **Plan**: [842_literature_convert_chunk_index_coverage/plans/01_coverage-fix-plan.md]
- **Summary**: [842_literature_convert_chunk_index_coverage/summaries/01_coverage-fix-summary.md]

**Description**: Fix the literature corpus chunk/index coverage gap surfaced (but deliberately left unfixed) by task #840's Job 4. ROOT CAUSE (verified by #840, re-verify before acting): `/literature --convert` converts a PDF/DJVU to markdown but NEVER invokes the chunker or the FTS5 indexer -- only `/literature --ingest` does. As a result documents that were converted (not ingested) have zero rows in the global `.literature.db` `chunks_data` table and are SILENTLY INVISIBLE to `literature-search.sh`, even though they appear in `index.json` and on disk.

MEASURED BASELINE (verified 2026-07-09/10 by #840, re-verify): 25 of 97 `sources/<dir>/` directories have zero `chunks_data` coverage, including non-quarantined docs `girard_1989`, `rabinovich_2014`, `burgess_1982_i`, `van_doorn_2015`. Task #840 added `/literature --rebuild` Job 4 which REPORTS this per-directory (use it to get the current exact list: `/literature --rebuild --dry-run` job 4). Also: the `document_metadata` table was observed EMPTY (0 rows) -- investigate whether that is the same population gap or a separate schema/population bug.

REQUIRED WORK:
1. Wire `--convert` to chunk+index the converted document the same way `--ingest` does (or make `--convert` call the ingest chunk/index path). Do NOT duplicate logic -- reuse `literature-chunk.sh` and the indexer.
2. Backfill the 25 (or current count) uncovered `verified_conversion` directories so every converted doc has `chunks_data` rows and is searchable.
3. Investigate and fix the empty `document_metadata` table if it is a bug.
4. Guard: extend `/literature --rebuild` Job 4 or add a check so a converted-but-unchunked doc is caught going forward.

CONSTRAINTS:
- SOURCE OF TRUTH is `.claude/extensions/literature/` -- implement there, not in deployed `.claude/scripts/` copies (tasks #841/#840 just reconciled that drift; a guard now catches divergence).
- EXCLUDE quarantine artifacts (`.md.bak-<UTC>`, `.md.rejected`, e.g. gabbay_2000) from chunking/indexing -- verify the chunker glob is strict; a chunked `.md.rejected` would inject a known-bad doc into search.
- Hazard from #832: `literature-ingest.sh` may write outside `sources/<dir>/`; ensure backfilled chunks land where the indexer scans.
- Quarantine-never-delete for any file moves. Do not mutate `index.json` entries beyond adding coverage.

VERIFICATION:
- After fix, `/literature --rebuild --dry-run` Job 4 reports 0 uncovered `verified_conversion` directories (down from 25).
- A newly `--convert`ed test document immediately has `chunks_data` rows and is returned by `literature-search.sh` without a separate `--ingest` step.
- `document_metadata` is populated (or the empty state is confirmed benign and documented).
- No quarantine artifact appears in `chunks_data`.

---

### 841. Reconcile literature extension source drift
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [841_reconcile_literature_extension_source_drift/reports/01_drift-audit.md]
- **Plan**: [841_reconcile_literature_extension_source_drift/plans/01_reconciliation-plan.md]
- **Summary**: [841_reconcile_literature_extension_source_drift/summaries/01_reconciliation-summary.md]

**Description**: Reconcile the literature extension SOURCE OF TRUTH (`.claude/extensions/literature/`) against the DEPLOYED COPIES (`.claude/scripts/`), which have drifted ahead by at least two prior tasks. A "Load Core" / extension sync currently reverts recent correctness fixes silently. This is a live regression risk, not cosmetic.

MEASURED DRIFT (verified 2026-07-09, re-verify before acting):
- `.claude/scripts/literature-search.sh` and `.claude/extensions/literature/scripts/literature-search.sh` DIFFER. Deployed has 2 `unadjudicated` references (task #839) and task #835's entire provenance/fidelity flagging block (the `--include-unverified` flag, quarantine-from-ranked-output logic, warning-banner-on-read). Extension source has ZERO `unadjudicated` refs and is missing the #835 block.
- `.claude/scripts/literature-briefing.sh` vs `.claude/extensions/literature/scripts/literature-briefing.sh` DIFFER. Deployed has 3 `unadjudicated` refs (task #839's `needs_fidelity_marker()` allowlist fix); extension source has 0.
- `.claude/scripts/literature-fidelity-audit.sh` exists ONLY in `.claude/scripts/` -- it is NOT in the extension at all. Task #839 fully owns this script. Decision required: does it belong in the extension source (so it survives sync), or is it intentionally repo-local? If it belongs in the extension, add it; if repo-local, document WHY and protect it.

CONSEQUENCE IF UNFIXED: next extension sync overwrites `.claude/scripts/` from the (stale) extension source. #839's fail-open fix downstream disappears -- `unadjudicated` docs stop getting warning banners in `literature-briefing.sh` and stop being quarantined from ranked search in `literature-search.sh`. #835's provenance flagging disappears entirely. The corpus index.json would still say `unadjudicated`, but no consumer would honor it. Silent re-introduction of the exact fail-open class #839 was created to eliminate.

ROOT CAUSE: tasks #835 and #839 (and possibly earlier literature tasks) edited the DEPLOYED `.claude/scripts/` copies directly instead of the extension source. `.syncprotect` at project root does NOT list any of these scripts (it currently lists only `context/repo/project-overview.md` and `output/implementation-001.md`), so they are unprotected.

REQUIRED WORK:
1. AUDIT the full drift surface. Do not assume it is only the two scripts above. Diff EVERY file that exists in both `.claude/scripts/` and `.claude/extensions/literature/scripts/`, and every `.claude/commands/literature.md` (+ cite.md) vs its extension-source counterpart. Produce a complete drift manifest before changing anything. Other literature scripts (build-index, chunk, ingest, discover, retrieve, normalize-authors, lit-flag-resolve, create-setup-task) may also have drifted.
2. For each drifted file, determine DIRECTION of truth. The deployed copies carry the newer correctness fixes (#835, #839), so in these known cases the deployed copy is authoritative and must be backported INTO the extension source. But verify per-file -- do not blindly assume deployed is always newer; a file could have been correctly edited in the extension and be behind in deploy. Use git history if needed.
3. BACKPORT the authoritative content into `.claude/extensions/literature/` source. After backport, deployed and extension-source copies of each reconciled file must be semantically equivalent (ignoring any legitimately deploy-local path substitutions the sync performs).
4. DECIDE and document the fate of `literature-fidelity-audit.sh` (add to extension source vs. keep repo-local-and-protected).
5. INSTALL A GUARD so this cannot silently recur. Options to evaluate (pick and justify): (a) a doc-lint / CI check in the spirit of `.claude/scripts/check-extension-docs.sh` that fails when a deployed `.claude/scripts/literature-*.sh` diverges from its extension source; (b) adding the fidelity-critical scripts to `.syncprotect` if they are legitimately repo-local; (c) a pre-sync verification step. A guard is REQUIRED, not optional -- without it the reconciliation decays again on the next hotfix.

CONSTRAINTS:
- Do NOT alter the RUNTIME BEHAVIOR of the deployed scripts. The deployed `.claude/scripts/` copies are the ones currently exercised by the live corpus and by tasks #832/#839's verified results. This task makes the EXTENSION SOURCE match them, plus a guard -- it must not regress what is deployed. After this task, re-running `literature-fidelity-audit.sh --dry-run` must produce byte-identical classification to before.
- Quarantine-never-delete posture for any file moves.
- If backporting reveals a genuine conflict (extension source has an intentional change the deployed copy lacks), STOP and report it rather than clobbering.

VERIFICATION:
- Drift manifest lists every literature file compared and its verdict.
- After backport: for each reconciled script, `diff` between deployed and extension source shows only expected/no differences.
- `grep -c unadjudicated` on the extension-source `literature-search.sh` and `literature-briefing.sh` matches the deployed copies (2 and 3 respectively, or whatever re-verification shows).
- The installed guard actually fails when fed an artificial divergence (test it, do not just add it).
- `literature-fidelity-audit.sh --dry-run` classification unchanged from pre-task baseline.

---

### 840. Literature rebuild subindex command
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: Task 841
- **Research**: [840_literature_rebuild_subindex_command/reports/01_rebuild-research.md]
- **Plan**: [840_literature_rebuild_subindex_command/plans/01_rebuild-plan.md]
- **Summary**: [840_literature_rebuild_subindex_command/summaries/01_rebuild-summary.md]

**Description**: Add a `--rebuild` flag to the `/literature` command that brings a repo's per-repo sub-index (`specs/literature-index.json`) into conformance with the global Literature corpus and current conventions.

MOTIVATION: The per-repo sub-index schema is `{"entries": [{"doc_id", "relevance", "source"}]}` -- key-based, resolved against `$LITERATURE_DIR/index.json` at read time. It caches NO `provenance_fidelity`, so old repos are NOT carrying stale fidelity stamps (verified: task #839's fail-open fix does not need backporting into sub-indexes). The real failure mode is COVERAGE DRIFT, not corruption: the global index has 273 doc ids and grew during tasks #836 (7 Zotero recoveries) and #832 (girard_1989, van_doorn_2015 added; 3 docs materially reconverted). A sub-index curated months ago has no mechanism to notice newly-relevant documents appeared. It does not go wrong -- it silently under-covers, which is harder to detect than a dangling reference.

MEASURED BASELINE (verified 2026-07-09, do not assume it still holds):
- `~/.config/nvim/specs/literature-index.json` -- ABSENT
- `~/Projects/BimodalLogic/specs/literature-index.json` -- 2 entries, 0 dangling
- `~/Projects/cslib/specs/literature-index.json` -- 11 entries, 0 dangling
- global `~/Projects/Literature/index.json` -- 273 doc ids
So dangling-ref lint currently PASSES on every live sub-index. It is a regression guard, not a fix for a present defect. Do not write the plan as though refs are currently broken.

INTERFACE DECISION (settled by user, do not relitigate): implement as `/literature --rebuild`, NOT a top-level `/rebuild` command. Rationale: `/literature` already owns `--validate` (global index vs filesystem), `--scan`, `--index FILE`. `--rebuild` sits beside `--validate` with a clean distinction -- `--validate` checks global-vs-filesystem; `--rebuild` checks per-repo-sub-index-vs-global. It also pairs with the existing `literature-create-setup-task.sh`, which already handles the sub-index-MISSING case; `--rebuild` is the sub-index-EXISTS-BUT-STALE counterpart. A bare `/rebuild` is ambiguous (rebuild what -- global index? search chunks? sub-index?) and duplicates skill-literature plumbing.

FOUR JOBS. On invocation, `--rebuild` MUST present an AskUserQuestion (multiSelect) letting the user choose which jobs to run. Do not hardcode running all four. Default selection may pre-check the two mechanical ones.

1. DANGLING-REF LINT (mechanical, idempotent, safe, non-interactive)
   For each `doc_id` in the sub-index, assert it resolves to an `.id` in the global index. Report unresolvable ids. Currently 0 across all live sub-indexes -- this is a guard against future reconversions renaming doc ids (e.g. #832's reconversions, venema_1991's per-chapter sub-document id namespace).

2. SCHEMA CONFORMANCE CHECK (mechanical, idempotent, safe, non-interactive)
   Verify each entry matches the current `{doc_id, relevance, source}` shape. Verify conformance to conventions that have accreted since the sub-index was authored -- notably `.claude/context/project/literature/patterns/chunk-file-conventions.md` (created by #839; documents that `chunk_NNNN.md` files are near-verbatim re-splits of the canonical `.md` and must never be double-counted). Report nonconforming entries.

3. COVERAGE REFRESH (requires LLM judgment; DRY-RUN AND CONFIRM, never autonomous)
   Scan the global index for documents newly relevant to this repo's domain but absent from the sub-index, using `project_tags`, `keywords`, and `summary` fields (the same signals `literature-create-setup-task.sh` already relies on). PROPOSE additions with a relevance annotation; do NOT write them without explicit user confirmation. `specs/literature-index.json` is a HUMAN-CURATED file -- an agent must not silently rewrite a human's curation decisions. Show a diff, then confirm.

4. CHUNK / SEARCH-INDEX COVERAGE AUDIT (mechanical, read-only)
   Assert every `verified_conversion` directory has chunk files AND corresponding search-index entries. This closes a gap left open by #832: its Phase 8 reported "4,002 chunks" as an AGGREGATE and never checked per-directory coverage. A count of 4,002 is equally consistent with "all covered" and "two silently missing". Assert per-directory, not in aggregate.
   Two known hazards this audit must specifically check:
   (a) `literature-ingest.sh` writes outside `sources/<dir>/` (reported by #832, worked around rather than fixed) -- newly-converted docs may land where the chunker/indexer does not scan. #832's two new conversions (girard_1989, van_doorn_2015) went through that path.
   (b) Quarantine artifacts must be EXCLUDED from chunking/indexing. #832 created four `.md.bak-<UTC>` files and one `.md.rejected` (gabbay_2000's 1.4 MB failed conversion). The fidelity audit's `*.md` glob does not match them, but it is UNVERIFIED whether the chunker's glob is equally strict. A chunked `.md.rejected` would inject a known-bad document into search results.

CONSTRAINTS:
- Jobs 1, 2, 4 are read-only and idempotent. Job 3 is the only one that writes, and only after confirmation.
- Never delete or rewrite a human-curated sub-index entry. Additions only; removals of dangling ids must be confirmed.
- Support `--dry-run` for all jobs.
- The command must work when the sub-index is ABSENT: in that case defer to the existing `literature-create-setup-task.sh` path rather than duplicating it.

FILE SCOPE NOTE (read before planning): `.claude/extensions/literature/` is the SOURCE OF TRUTH. `.claude/commands/` is a DEPRECATED legacy mirror and `.claude/scripts/` holds DEPLOYED COPIES. Edits belong in the extension. Note that recent literature work (#835, #839) edited the deployed copies directly and the extension source is now behind -- see the companion drift task. Do not repeat that mistake: implement `--rebuild` in the extension source and let the deploy/sync mechanism propagate it.

VERIFICATION:
- `--rebuild --dry-run` against `~/Projects/cslib` (11 entries) and `~/Projects/BimodalLogic` (2 entries) must report 0 dangling refs and 0 schema violations, matching the measured baseline above.
- `--rebuild` against `~/.config/nvim` (sub-index ABSENT) must route to the create-setup-task path, not error.
- Job 4 must be run against the live corpus and must either confirm per-directory chunk coverage for all `verified_conversion` dirs or name the ones missing coverage.
- Confirm no job mutates the corpus or the sub-index without confirmation.

---

### 839. Fix fail-open classification in literature-fidelity-audit.sh
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [839_fix_fidelity_audit_fail_open/reports/01_fidelity-audit-fail-open.md]
- **Plan**: [839_fix_fidelity_audit_fail_open/plans/01_fix-fidelity-audit-fail-open.md]
- **Summary**: [839_fix_fidelity_audit_fail_open/summaries/01_fix-fidelity-audit-fail-open-summary.md]

**Description**: Fix the fail-open classification bug in .claude/scripts/literature-fidelity-audit.sh, which silently stamps provenance_fidelity="verified_conversion" onto documents it could not actually adjudicate.

THE BUG (verified by reading the script and by running `literature-fidelity-audit.sh --dry-run` against the live corpus):

At lines 367-374, classify_dir() takes this branch:

    frac, adequate, total = proof_completeness_fraction(md_texts)
    if frac is None:
        # "this corpus is formal-math-heavy and every low-ratio case observed
        #  carries numbered statements"
        result["provenance_fidelity"] = "verified_conversion"
        return result

So a document with word_ratio far below RATIO_THRESHOLD (0.75), disclosed=False, and NO numbered statements to check gets labeled verified_conversion by default. The signal that would have caught it cannot fire, and the absence of that signal is read as a pass.

The inline comment justifies this by asserting "every low-ratio case observed carries numbered statements." That assumption was true of the corpus #835 measured. It is now FALSIFIED: task #836 recovered PDFs for prose philosophy papers that carry no numbered theorems.

MEASURED VICTIMS (disclosed=False, proof_fraction=None, stamped verified_conversion):
  fine_2012_guide-to-ground                         word_ratio=0.0327   (677 md words vs 20,701 pdf words)
  fine_2012_counterfactuals-without-possible-worlds word_ratio=0.2455   (2,960 vs 12,056)
  venema_1991                                       word_ratio=0.3737   (22,623 vs 60,541)

A 677-word stub against a 20,701-word PDF is a hand-written summary, not a verified conversion. The corpus currently asserts otherwise.

DO NOT BREAK THE LEGITIMATE BRANCH: doets_1987 (ratio=0.2378) and libkin_2004_ch3_ch7 (ratio=0.0187) are also low-ratio, but have disclosed=True. These are the documented partial conversions from #835. The disclosure branch (line 361) is correct and must keep passing them.

REQUIRED FIX: when the proof-completeness signal cannot fire (frac is None) on a low-ratio, undisclosed document, the honest result is a distinct value meaning "could not adjudicate" -- NOT verified_conversion. Introduce a sixth enum value (suggested: `unadjudicated`) rather than overloading unverified_summary, which asserts a positive finding the audit did not make. Fail closed, never open.

CONSEQUENT WORK:
- Update the five-value enum contract (currently documented at the script header, ~line 38) to six values, and update every consumer of provenance_fidelity. Known consumers: `.claude/scripts/literature-build-index.sh`, `literature-search.sh` (surfaces provenance_fidelity in result rows), and task #832 s cohort logic.
- Re-run `--write` after the fix so the 3 victim dirs are re-stamped honestly.
- #835 s report (`01_provenance-fidelity-audit.md`) documents this branch as accepted residual risk. Update that record; the risk is now realized, not residual.

SECONDARY DEFECT (same file, lower severity, no upper ratio bound): the `ratio >= RATIO_THRESHOLD` test at line 354 has no upper bound, so a markdown file with FAR MORE words than its PDF passes unexamined. Observed: fine_2010_some-puzzles-of-ground (2.08), fine_2012_pure-logic-of-ground (1.91), bacon_2018_broadest-necessity (1.78). Plausibly pdftotext under-extracting two-column math rather than corrupted markdown -- but nothing checks, and a ratio of 2.08 is not evidence of a faithful conversion. Investigate; add an upper sanity bound or an explicit documented exemption.

VERIFICATION: `--dry-run` is report-only and never writes index.json -- use it freely. After the fix, `--dry-run` must show the 3 victim dirs as unadjudicated (or equivalent), doets_1987 and libkin_2004_ch3_ch7 still verified_conversion via disclosure, and rabinovich_2014 still unverified_summary (proof_fraction=0.545 < 0.6). Confirm `--write` remains idempotent.

CONTEXT: discovered while orchestrating #836 (Zotero PDF recovery) and preparing the second /revise of #832. Task #832 was explicitly amended to WORK AROUND this bug (treating the 3 unadjudicated dirs as reconversion candidates) rather than fix it, because the audit script is outside #832 s file_scope. This task is the real fix.

---

### 838. Fix planner clobbering researcher .return-meta.json (merge not overwrite)
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: General skill-lifecycle data-loss bug: the planner-phase postflight OVERWRITES the researcher's specs/{NNN}_*/.return-meta.json wholesale instead of MERGING, silently dropping memory_candidates the research agent emitted. Concrete instance: on task #831 the planner clobbered .return-meta.json, destroying 3 memory_candidates the research agent produced - (a) nix-ld/libstdc++ shim, (b) PyMuPDF sort=True reproduces the column-glue extraction bug, (c) NFKC normalization corrupts math Unicode. This affects EVERY task where research emits memory_candidates and a later phase rewrites the file, not just literature work - which is why it warrants its own task rather than folding into #835-#837 (all unrelated in scope). FIX SITE: .claude/context/formats/return-metadata-file.md (the contract) plus the skill postflight metadata-handling code - change semantics from overwrite to merge-not-overwrite so later phases preserve earlier phases' memory_candidates and other accumulated fields. Fully independent of #831-#837.

---

### 837. Fix .claude/ cross-project contract drift and add dangling-reference lint
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: agent-system
- **Dependencies**: None

**Description**: Shared .claude/ infrastructure has diverged across child projects and nothing detects dangling references at sync/load time - the same silent-degradation failure mode as #831's missing marker. IMPORTANT correction of the original bug report, which was MISATTRIBUTED to nvim: this repo (~/.config/nvim/.claude/) is HEALTHY - context/contracts/ contains all 8 of adversarial-verification, anti-analysis, convergence, orchestrator-discipline, recovery, reference-grounding, territory, wrap-up; its skill-orchestrate-hard/SKILL.md references 6, all present. The real defect is in ~/Projects/BimodalLogic/.claude/ - a SEPARATE COPY, not a symlink - whose skill-orchestrate-hard references 5 contracts it LACKS, so H5/H6/H7/H9 are silently un-injected. Drift is BIDIRECTIONAL: only-in-BimodalLogic = context-hygiene.md; only-in-nvim = convergence.md, orchestrator-discipline.md, recovery.md, territory.md, wrap-up.md. SCOPE: (1) reconcile contracts/ across ~/.config/nvim/.claude/ and ~/Projects/BimodalLogic/.claude/, sweeping other child projects (e.g. cslib); (2) decide the canonical set (is context-hygiene.md a real contract nvim should adopt?); (3) add a validator - extend check-extension-docs.sh or add a sibling script - that FAILS when any skill/agent/rule references a contracts/*.md, @.claude/... path, or context file absent in that project; (4) wire it into the sync path (.syncprotect / 'Load Core') so drift is caught at load time. LOUD-FAILURE requirement: a missing contract must not silently no-op. Fully independent of #831-#836 and #838.

---

### 836. Recover source PDFs via Zotero for PDF-less central dirs
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 835
- **Research**: [836_recover_source_pdfs_via_zotero/reports/01_recover-source-pdfs-zotero.md]
- **Plan**: [836_recover_source_pdfs_via_zotero/plans/01_recover-source-pdfs-zotero.md]
- **Summary**: [836_recover_source_pdfs_via_zotero/summaries/01_recover-source-pdfs-zotero-summary.md]

**Description**: Recover source PDFs for the 52 central dirs under ~/Projects/Literature/sources/ that lack a source PDF (49 chunk-bearing + 3 empty - two different populations; address all 52). Zotero is the ONLY viable recovery source: ~/Projects/Literature/zotero-library.json exists (173 KB, 400 entries) and index.json entries carry zotero_key and zotero_path fields. SCOPE: re-resolve zotero_key/zotero_path against the Zotero library and its storage dir for the 52 PDF-less dirs; repopulate ~/Projects/Literature/pdfs/ symlinks; report which of the 52 remain unrecoverable after Zotero resolution and mark them no_source_pdf, never silently retained as authoritative. Likely entry point: .claude/scripts/zotero-resolve-sqlite-path.sh already exists and is probably the right starting point. VERIFIED - do NOT re-investigate per-repo copies: they yield ZERO unique PDFs (~/Projects/BimodalLogic/specs/literature/sources = 31 pdfs but 0 unique vs central; ~/Projects/cslib/specs/literature/sources = 0 pdfs; ~/Projects/cslib-refactor-prop_logic/specs/literature/sources = 0 pdfs). There is NO ordering constraint against #834 - deleting BimodalLogic's sources/ destroys zero unique recovery sources (central-lacks-PDF intersect BimodalLogic-has-PDF = 0). DEPENDENCY: depends on #835 via file-footprint overlap - both write ~/Projects/Literature/index.json, where 835 DEFINES the provenance/fidelity enum and 836 WRITES one of its values (no_source_pdf); schema must precede population.

---

### 835. Literature corpus provenance and fidelity audit
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md]
- **Plan**: [835_literature_corpus_provenance_fidelity_audit/plans/01_provenance-fidelity-flagging.md]
- **Summary**: [835_literature_corpus_provenance_fidelity_audit/summaries/01_provenance-fidelity-flagging-summary.md]

**Description**: Provenance/fidelity defect orthogonal to #831's four extraction bugs. Many literature dirs are not badly converted - they were never converted; the .md is a hand-authored paraphrase that reads as authoritative and the index blesses it with a token count, so agents ground formal work on a summary that never contained the lemma it cites. VERIFIED: of 97 dirs under ~/Projects/Literature/sources/, populations are: 0 healthy (PDF AND chunks), 45 PDF+zero-chunks (never converted; .md is a hand-written stand-in), 49 chunks+no-PDF (converted but source PDF absent, not reconvertible), 3 neither. Word-ratio (md_words/pdf_words) on PDF-bearing dirs shows systematic summary-substitution: blackburn_2002=0.03, baier_katoen_2008=0.10, caleiro_2013=0.09, doets_1987=0.11, gabbay_1993=0.15, goldblatt_2003=0.25, rabinovich_2014=0.29, doets_1989=0.36, derijke_1995=0.44, hodkinson_2006=0.57. Concrete exemplar: rabinovich_2014 .md = 245 lines / 2,093 words (opens '## Overview\nProvides a simple, self-contained proof of Kamp's theorem...' - editorial prose), sibling PDF = 16 pages / 7,296 words, index.json holds ONE entry id=rabinovich_2014 token_count=2721; Lemma 3.2(1) is a single unproved sentence, Definition 7.13 is one line. SCOPE: (1) classify every dir into the four populations; (2) build a detector for 'md is a hand-authored summary, not a conversion of the sibling PDF' using word-ratio threshold, absence of chunk_*.md, prose markers (leading '## Overview'), absence of the PDF's section headings, missing numbered lemma/definition bodies; (3) record a provenance/fidelity field per index.json entry with values verified_conversion / unverified_summary / no_source_pdf; (4) make literature-briefing.sh and literature-search.sh LOUDLY flag low-fidelity entries rather than serving them as authoritative; (5) quarantine, never delete. KEY INSIGHT to record for downstream: corrupt column-interleaved text announces itself, a fluent hand-written summary does not - which is exactly why fidelity needs its own gate, the fidelity analogue of #831's quality gate. Independent of #831-#834. NOTE: #832's 'reconvert all 97 dirs' premise is invalidated by this finding (52 have no PDF; 45 need .md replacement, not re-derivation) - #832 carries deps [835,836] as a premise interlock and should be /revised once 835/836 land.

---

### 834. Retire stale per-repo literature copies (FINDING 6)
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [834_retire_stale_per_repo_literature_copies/reports/01_retire-stale-literature-copies.md]
- **Plan**: [834_retire_stale_per_repo_literature_copies/plans/01_retire-stale-literature-copies.md]
- **Summary**: [834_retire_stale_per_repo_literature_copies/summaries/01_retire-stale-literature-copies-summary.md]

**Description**: Retire the stale per-repo literature copies. FINDING 6: the architecture is ALREADY correct (central store + per-repo index, no document duplication) - the cleanup simply never happened. ~/Projects/BimodalLogic/specs/literature/ is 181 MB with 27 source dirs, and ALL 27 already exist in ~/Projects/Literature/sources/ (97 dirs total). A DEPRECATED.md there records migration completed 2026-06-14 under task 710, and LITERATURE_DIR is already wired into both .claude/settings.json and home.nix. Verify content equivalence of the 27 BimodalLogic source dirs against central, confirm the per-repo specs/literature-index.json sub-index convention works end-to-end (currently unclear whether it is populated anywhere), then delete ~/Projects/BimodalLogic/specs/literature/sources/. Sweep ~/Projects/ for other stale specs/literature/ copies. Keep DEPRECATED.md in place. Scope as verify-then-delete + confirm the sub-index convention works, NOT as a re-migration. Independent - no dependencies.

---

### 833. Harden retrieval against tokenization brittleness
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 831
- **Research**: [833_harden_literature_retrieval_tokenization/reports/01_harden-retrieval-tokenization.md]
- **Plan**: [833_harden_literature_retrieval_tokenization/plans/01_harden-retrieval-tokenization.md]
- **Summary**: [833_harden_literature_retrieval_tokenization/summaries/01_harden-retrieval-tokenization-summary.md]

**Description**: Harden .claude/scripts/literature-search.sh and literature-briefing.sh so tokenization brittleness degrades gracefully. Triggering symptom (a symptom, not the disease): an agent dead-ended with 'FTS5 chokes on the punctuation; the research agent will read the chunk directly', surfaced while working on ~/Projects/BimodalLogic/specs/337_build_joint_multiowner_disjunct_bracketholds_engine_for_kve2_sepdisjunct/plans/04_joint-disjunct-holds-codesign.md. Normalize the search query using the SAME normalization applied to the corpus in #831; on zero-results or an FTS5 parse failure, fall back gracefully (trigram/LIKE, or sqlite-vec semantic search per the draperlaboratory/pdf2sqlite design, which would make retrieval resilient to exactly this punctuation/tokenization brittleness). Evaluate storing a per-chunk LLM-generated 'gist' alongside text for searchable summaries. Ensure literature-briefing.sh surfaces a usable next action rather than leaving the agent to improvise 'I'll just read the chunk directly.' System ALREADY has literature-schema.sql + FTS5 (chunks_fts, bm25) - this is augmentation, not a rewrite. Depends on #831; can run parallel to #832.

---

### 832. Reconvert and validate the literature corpus (BUG 5)
- **Status**: [PARTIAL]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: Task 831, Task 835, Task 836, Task 839
- **Research**: [832_reconvert_and_validate_literature_corpus/reports/01_reconvert-validate-corpus.md]
- **Plan**: [832_reconvert_and_validate_literature_corpus/plans/01_reconvert-validate-corpus.md]
- **Summary**: [832_reconvert_and_validate_literature_corpus/summaries/01_reconvert-validate-corpus-summary.md]

**Description**: Reconvert and validate the actionable portion of the ~/Projects/Literature corpus, driven by the measured provenance/fidelity classification that task #835 established and stamped onto ~/Projects/Literature/index.json, as corrected by the re-derivation performed after #836 landed. The original "reconvert and validate all 97 source dirs" premise is dead, and so are the earlier "verified facts" that replaced it: the "ZERO are healthy / 45 dirs are hand-written summaries" figures and the cited word-ratios (blackburn_2002 = 0.03, rabinovich_2014 = 0.29) were artifacts of a single-file-sampling bug (comparing one arbitrary .md file against the entire PDF). Aggregated at the whole-document level, nearly every cited case is a healthy conversion, and blackburn_2002 is in fact a verified conversion. Drop all of those numbers rather than restating them.

MEASURED CLASSIFICATION (authoritative, re-derived post-#836 via `literature-fidelity-audit.sh --dry-run`). Two real granularities exist; state which you mean and never conflate them.
At DIRECTORY level (97 dirs total):
- 45 no_source_pdf         — no PDF present; cannot be reconverted
- 42 verified_conversion   — stamped healthy, but see the UNADJUDICATED caveat below
- 5  not_yet_converted     — PDF present, zero markdown (already self-disclosed)
- 4  unverified_no_baseline — PDF present but `pdftotext -layout` extracts 0 words; ratio undeterminable
- 1  unverified_summary    — rabinovich_2014, the ONLY confirmed undisclosed paraphrase
At index-ENTRY level (153 entries): 91 verified_conversion, 45 no_source_pdf, 15 unverified_no_baseline, 1 not_yet_converted, 1 unverified_summary.

THE STAMP IS NOT FULLY TRUSTWORTHY (read before acting on any classification). `.claude/scripts/literature-fidelity-audit.sh` FAILS OPEN at lines 367-374: when a document has word_ratio < 0.75, disclosed = False, AND proof_fraction = None (no numbered statements available to check), it defaults the document to `verified_conversion`. Its inline comment justifies this by assuming "every low-ratio case observed carries numbered statements" — an assumption FALSIFIED by the PDFs #836 recovered, which include prose philosophy papers with no numbered theorems. Three directories are therefore stamped `verified_conversion` while being genuinely UNADJUDICATED:
- fine_2012_guide-to-ground                         ratio = 0.0327 (677 md words vs 20,701 pdf words)
- fine_2012_counterfactuals-without-possible-worlds ratio = 0.2455 (2,960 vs 12,056)
- venema_1991                                       ratio = 0.3737 (22,623 vs 60,541)
Two other low-ratio dirs — doets_1987 (0.2378) and libkin_2004_ch3_ch7 (0.0187) — carry disclosed = True. Those are the LEGITIMATE documented partial conversions. Do not touch them.

REMAINING WORK — 13 ACTIONABLE DIRS, SCOPED PER COHORT (touch only the cohorts that need work):
- 5 not_yet_converted dirs (gabbay_2000, girard_1989, negri_von_plato_2001, troelstra_schwichtenberg_2000, van_doorn_2015) — the only greenfield conversion work. Run the fixed converter from #831 (COMPLETE). Treat converter exit code 3 as skip+log (a loud quality-gate failure), NEVER as success. Goldblatt/Hodkinson/Venema 2003 is a known document that fails the primary tier and must be routed with LITERATURE_CONVERTER=pymupdf.
- 3 unadjudicated dirs (fine_2012_guide-to-ground, fine_2012_counterfactuals-without-possible-worlds, venema_1991) — RECONVERSION CANDIDATES despite their `verified_conversion` stamp. The two Fine papers have real PDFs thanks to #836; venema_1991 had a PDF all along. Reconvert from the PDF and compare.
- 4 unverified_no_baseline dirs (burgess_1984, gabbay_1994, thomason_1984, vardi_wolper_1986) — NOT reconversion. Their PDFs yield 0 words under pdftotext (scanned/image PDFs), so they need a baseline-extraction fix (OCR-based re-extraction, e.g. ocrmypdf/pytesseract) so a ratio becomes computable; then re-run the fidelity audit to confirm/promote.
- 1 unverified_summary dir (rabinovich_2014) — REPLACE its .md with a real conversion derived from its sibling PDF (a PDF is present), then re-run `literature-fidelity-audit.sh` to reclassify.
- Remaining verified_conversion dirs (the 42 minus the 3 unadjudicated above) — no action.
- 45 no_source_pdf dirs — OUT OF SCOPE. #836 RAN and resolved the question: it recovered 7 of the original 52 from Zotero, and the remaining 45 are CONFIRMED ABSENT from the Zotero library (not merely unmatched). They are not "gated pending #836"; they need a different acquisition route entirely, which belongs to a separate sourcing task.

REVALIDATION HALF (still real, still worth doing): now that a fixed converter (#831) and a provenance field (#835) both exist, rebuild/validate the corpus index via `.claude/scripts/literature-build-index.sh`, and re-run the fidelity audit after any conversion so newly-converted dirs receive a fresh `provenance_fidelity` + `word_ratio` stamp. Any residue that still lacks a PDF stays no_source_pdf.

CONSTRAINTS:
- Trust #835's stamped `provenance_fidelity` EXCEPT where (word_ratio < 0.75 AND disclosed = False AND proof_fraction = None). Those entries are UNADJUDICATED, not verified, and must be treated as reconversion candidates.
- Aggregate word-ratio at the WHOLE-DOCUMENT level, never single-file.
- Quarantine-never-delete posture throughout.
- Converter exit code 3 = skip + log, never success.
- Goldblatt/Hodkinson/Venema 2003 must route with LITERATURE_CONVERTER=pymupdf.
- The 45 no_source_pdf dirs are out of scope for this task.

SCOPE BOUNDARY: fixing the fail-open in `literature-fidelity-audit.sh` is task #839 (Fix fail-open classification in literature-fidelity-audit.sh). 832's file_scope is `~/Projects/Literature/sources/` and `.claude/scripts/literature-build-index.sh`; the audit script is NOT in scope. 832 must WORK AROUND the fail-open by treating the 3 unadjudicated dirs as reconversion candidates — do not fix the script here. Re-run the audit only AFTER #839 lands; otherwise accept that re-running it will re-stamp those 3 dirs as `verified_conversion` again.

RESIDUAL RISK (note, not work): the audit has no UPPER ratio bound — fine_2010_some-puzzles-of-ground (2.08), fine_2012_pure-logic-of-ground (1.91), and bacon_2018 (1.78) pass unexamined because they clear the >= 0.75 floor. Plausibly pdftotext under-extracting math, but nothing checks.

STATUS: BLOCKED on #839 (audit fail-open fix). #831/#835/#836 are all complete, so the corpus work itself is fully specified and ready; the remaining gate is #839, which also serializes on the shared file `.claude/scripts/literature-build-index.sh`. All 13 actionable dirs (5 not_yet_converted + 3 unadjudicated + 4 unverified_no_baseline + 1 unverified_summary) can be executed against #831's fixed converter and #835's classification, with the unadjudicated caveat applied.

DEPENDENCIES: 831 (COMPLETE — fixed converter), 835 (COMPLETE — provenance/fidelity classification), 836 (COMPLETE — Zotero PDF recovery; 7 recovered, 45 confirmed absent), 839 (NOT STARTED — audit fail-open fix; both a correctness prerequisite for the final re-audit and a file_scope conflict on literature-build-index.sh).

---

### 831. Fix literature conversion pipeline correctness (BUGS 1-4)
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: literature
- **Dependencies**: None
- **Research**: [831_fix_literature_conversion_pipeline_correctness/reports/01_conversion-pipeline-fix.md]
- **Plan**: [831_fix_literature_conversion_pipeline_correctness/plans/01_conversion-pipeline-fix.md]
- **Summary**: [831_fix_literature_conversion_pipeline_correctness/summaries/01_conversion-pipeline-fix-summary.md]

**Description**: Fix silent conversion-correctness bugs in .claude/scripts/literature-convert.sh. BUG 1 (ROOT CAUSE): converter prefers marker/marker_single, but marker_single is NOT installed on this machine, so every corpus doc fell back to `pdftotext -layout`, which glues two-column academic layouts side-by-side into semantic garbage (verified in ~/Projects/Literature/sources/alur_2013_syntax-guided-synthesis/chunk_0012.md). Make converter selection explicit and LOUD, never silently degrade to a layout-destroying engine. Evaluate/require marker, or pymupdf4llm/docling/nougat, or replace the -layout path with column-aware PyMuPDF page.get_text("blocks"/"dict") reading-order extraction (never -layout on multi-column). BUG 2: literature-convert.sh:171 `for pg in range(start_page, min(end_page, start_page + 3))` silently truncates each TOC section to its first 3 pages (unbounded data loss) - remove it. BUG 3: 2,351 chunk files match `^(.+) > \1$` (doubled breadcrumb headers); no-TOC docs derive headings from sentence fragments (e.g. ~/Projects/Literature/wdb.cariani.santorio/chunk_0010.md begins 'indeterminacy. > indeterminacy.'). Fix heading derivation and doubled breadcrumbs. BUG 4: 64 markdown files contain raw U+FB00-U+FB06 ligatures (swordﬁsh, identiﬁ) that FTS5 unicode61 won't decompose; add NFKC/ligature folding, dehyphenation across line breaks, and soft-wrap rejoining. Add a conversion-quality gate that FAILS LOUDLY rather than emitting corrupt markdown: column-interleaving heuristic, page-coverage assertion against len(doc), ligature scan. HIGH priority - blocks #832 and #833. Evidence pre-verified; no need to re-derive.

---

### 830. Aerc terminal ctrl hjkl esc passthrough
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: Terminal UI
- **Dependencies**: None
- **Research**: [830_aerc_terminal_ctrl_hjkl_esc_passthrough/reports/01_aerc-terminal-passthrough-research.md]
- **Plan**: [830_aerc_terminal_ctrl_hjkl_esc_passthrough/plans/01_aerc-terminal-passthrough.md]
- **Summary**: [830_aerc_terminal_ctrl_hjkl_esc_passthrough/summaries/01_aerc-terminal-passthrough-summary.md]

**Description**: Special-case the aerc terminal in Neovim's terminal-mode keymap setup so <C-h/j/k/l> and <Esc> reach aerc instead of being intercepted by Neovim. This is the cross-repo companion to .dotfiles task 105 Recommendation B (aerc<->nvim/himalaya keymap alignment); it is a hard PREREQUISITE for the aerc-side <C-hjkl> folder binds in that task.

BACKGROUND: aerc is launched via <leader>me into a floating toggleterm (lua/neotex/plugins/tools/mail.lua, cmd="aerc"). Every terminal matches the term://* TermOpen autocmd (lua/neotex/config/autocmds.lua:25) which calls set_terminal_keymaps() (lua/neotex/config/keymaps.lua:116). aerc is neither the is_claude nor is_opencode special case, so it falls through to the generic else branch (keymaps.lua:147-150) that maps terminal-mode <C-h/j/k/l> -> wincmd h/j/k/l, and the <Esc> -> <C-\><C-n> exit-terminal map (keymaps.lua:133). Result: aerc NEVER receives <C-hjkl> (they navigate Neovim windows) or <Esc> (it drops to Neovim normal mode instead of cancelling aerc's :prompt / :search / selection).

CHANGE: add an is_aerc detection alongside is_claude/is_opencode (match the terminal bufname/cmd for 'aerc'), and for aerc terminals (1) SKIP the <C-h/j/k/l>->wincmd remaps so they pass through to aerc, and (2) SKIP the <Esc>->exit-terminal remap (extend the existing `if not is_claude` guard to also exempt aerc) so aerc prompts cancel with Esc. This is safe because the aerc window is a fullscreen float with no sibling Neovim windows, so wincmd h/j/k/l do nothing useful there anyway. The change MUST be strictly gated on is_aerc: claude, opencode, and generic terminals keep their current <C-hjkl>/<Esc> behavior unchanged.

AFTER THIS LANDS: the .dotfiles task 105 side binds aerc's <C-h>/<C-l> = :prev-folder/:next-folder (or <C-j>/<C-k> = message nav) in modules/home/email/aerc.nix. That aerc-side edit is out of scope here.

FILES: lua/neotex/config/keymaps.lua (set_terminal_keymaps, ~L116-158). Reference only: lua/neotex/config/autocmds.lua:25 (the term://* trigger), lua/neotex/plugins/tools/mail.lua (the <leader>me launcher).

VERIFICATION: open aerc via <leader>me; confirm (once the aerc.nix binds exist) <C-hjkl> reach aerc and <Esc> cancels an aerc :prompt from inside the float; confirm a Claude Code terminal and a general :terminal STILL have working <C-hjkl> window-nav and <Esc> exit (no regression from the is_aerc gate).

CROSS-REPO: research + rationale in ~/.dotfiles/specs/105_aerc_keybindings_nvim_himalaya_alignment/reports/01_aerc-keymap-alignment.md (esp. §4 reachability table and §6.2 Recommendation B). Companion .dotfiles task 105.

---

### 829. Add leader vl piper tts read buffer
- **Status**: [COMPLETED]
- **Task Type**: neovim
- **Topic**: neovim
- **Dependencies**: None
- **Research**: [829_add_leader_vl_piper_tts_read_buffer/reports/01_piper-tts-toggle-research.md]
- **Plan**: [829_add_leader_vl_piper_tts_read_buffer/plans/01_piper-tts-toggle.md]

**Description**: Add <leader>vl toggle mapping that uses piper TTS to read the current buffer aloud from the cursor position to end of buffer, stopping playback when toggled off

---

### 828. Resolve Logos Trash/Archive UID collisions via live IMAP verification
- **Effort**: 3-4 hours
- **Status**: [COMPLETED]
- **Task Type**: nix
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [826_logos_maildir_duplication_mbsync_repair/reports/02_spawn-analysis.md]
- **Plan**: [828_logos_trash_archive_uid_collision_repair/plans/01_logos-uid-collision-repair.md]
- **Summary**: [828_logos_trash_archive_uid_collision_repair/summaries/01_logos-uid-collision-repair-summary.md]

**Description**: Build and run a live-IMAP-verified, rename-only repair for the 862 duplicate-UID pairs left unresolved by task 826's Phase 5 (860 in ~/Mail/Logos/.Trash/cur, 2 in ~/Mail/Logos/.Archive/cur). Task 826's implementation verified that all 862 pairs have DIFFERENT Message-Id values between the two colliding files -- these are distinct, irreplaceable real messages that collided on the same local U=NNN slot due to a corrupted, non-monotonic Near-side UID counter from the 2026-02-09 import (see specs/826_logos_maildir_duplication_mbsync_repair/handoffs/phase-5-blocker-report.md). No Message-Id-based delete is safe.

Scope: For each colliding UID, perform a live IMAP UID FETCH/Message-Id lookup against the ProtonMail Bridge server for the current Far-side UID assignment of the affected folder (.Trash or .Archive), compare it against each local candidate file's Message-Id, and where a match is found on one member of the pair, rename the OTHER (non-matching) member's Maildir filename to a fresh, non-colliding U=NNN token. Rename only -- never delete either file, never write/push anything to the server via this task's own script. Build a dry-run mode that lists all planned renames before executing any of them. Validate the technique end-to-end on the 2 tractable .Archive pairs first, then apply the same script to the 860 .Trash pairs. Use the existing Phase 1 backup at ~/Mail/.logos-backup-20260706/ (tarballs, mbsyncstate/uidvalidity snapshots, baseline counts) as the rollback source, and log every rename decision (matched/renamed, which file, old and new UID token) to a new artifact under that backup directory.

Explicitly out of scope (left for task 826 to resume afterward): running `mbsync logos`, clearing/resetting .mbsyncstate or .uidvalidity, lifting email-freeze, notmuch reindexing. Do not re-verify Message-Id distinctness (already established) or re-run Phase 3's Labels-mirror analysis (separate, already-decided concern). Ground the implementation in specs/826_logos_maildir_duplication_mbsync_repair/handoffs/phase-5-blocker-report.md (resolution path 1) and the Phase 5 section of specs/826_logos_maildir_duplication_mbsync_repair/plans/01_logos-mbsync-maildir-repair.md.

Definition of done: `ls ~/Mail/Logos/.Trash/cur | grep -oE 'U=[0-9]+' | sort | uniq -d` and the equivalent for .Archive/cur both return nothing (one physical file per UID), zero files deleted, zero server-side writes performed by this task's script, and a decision log written to the Phase 1 backup directory documenting every rename.

---

### 827. Redesign the /email staleness detector - stop equating maildir files with deduped messages
- **Status**: [BLOCKED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 826

**Description**: The freshness gate shipped in tasks 823-825 is defective: email-census compares `himalaya -f INBOX` maildir FILE count against `notmuch count folder:X` deduped-MESSAGE count. These are incomparable (different file sets; heavy label-folder duplication; Message-ID dedup), so the line reads [STALE] even immediately after a full email-reindex (observed live: on-disk=3736 vs notmuch-indexed=3735, and `notmuch count --output=files folder:Logos`=11075 - none agree). As a hard gate requiring [ok] it is unreachable, forcing a manual 'Proceed, accept N' override on every --all run. Redesign options to evaluate: (a) compare comparable file sets - on-disk files vs `notmuch count --output=files` for the EXACT indexed path (path:<acct>/cur); (b) downgrade from a hard equality gate to a 'notmuch grossly behind disk' ratio/threshold heuristic that can actually reach a passing state and only blocks on large lags; (c) make the real gate 'was email-reindex run this session?' rather than a count comparison. Update census.nix (freshness line), skill-email-cleanup Stage 1 gate, staleness-detection.md, and wrapper-contracts.md section 13. Depends on 826 because the correct true count depends on resolving the Logos maildir duplication first. Cross-repo: census.nix change lands in ~/.dotfiles.

---

### 826. Investigate Logos maildir file-duplication and repair broken mbsync logos sync
- **Status**: [BLOCKED]
- **Task Type**: nix
- **Topic**: extensions
- **Dependencies**: None
- **Research**:
  - [826_logos_maildir_duplication_mbsync_repair/reports/01_logos-maildir-mbsync-diagnosis.md]
  - [826_logos_maildir_duplication_mbsync_repair/handoffs/phase-7-blocker-report.md]
- **Plan**: [826_logos_maildir_duplication_mbsync_repair/plans/01_logos-mbsync-maildir-repair.md]
- **Summary**:
  - [826_logos_maildir_duplication_mbsync_repair/summaries/01_logos-mbsync-maildir-repair-summary.md]
  - [826_logos_maildir_duplication_mbsync_repair/summaries/02_phase7-reconcile-attempt-summary.md]

**Description**: Root-cause and fix the pre-existing Logos (Protonmail Bridge) mail infrastructure problem exposed by /email --logos --all (2026-07-05). Symptoms: (1) severe maildir file duplication - path:Logos/cur holds 8448 files for only 2869 unique Message-IDs (~3x), and folder:Logos spans 3735 messages / 11075 files; the Gmail-labels-over-IMAP pattern stores one message under many .Labels.* folders. (2) `mbsync logos` reconcile exits non-zero after mutations with: duplicate UIDs in .Trash/.Archive, a Maildir++ dotted-folder problem on `.Labels.benbrastmckie@gmail.com` (a dot in the folder name), and a draft with a missing Date header. Consequence: 161 local deletes from the recent cleanup are staged in local Logos Trash but CANNOT be pushed to the Proton server. Investigate ~/.dotfiles/modules/home/email/mbsync.nix (logos group/channels), notmuch.nix, and protonmail.nix; determine whether the .Labels.* folders should be excluded from the logos mbsync channels, whether Bridge label-folders are double-synced, and how to resolve the duplicate-UID and dotted-folder errors. Cross-repo: fixes land in ~/.dotfiles (deliberate handoff). Deliver a diagnosis + a concrete mbsync/notmuch config fix and a maildir de-duplication/cleanup plan. Do NOT run /email --logos --sync until this is fixed.

---

### 825. Wire detect->remediate->re-run into the --all coverage contract and docs
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 823, Task 824

**Description**: Synthesis/documentation task closing the loop opened by 823 (detection) and 824 (remediation). Update commands/email.md (add the staleness->remediation flow to Workflow Execution and Error Handling), EXTENSION.md, README.md, and the archive-mode-risk.md / bulk-bucket-review.md context so the --all whole-mailbox coverage promise is EXPLICITLY conditioned on a fresh notmuch index, and the end-to-end flow (detect staleness -> recommend/run sanctioned reindex or --sync -> re-run --all) is documented consistently across command, skill, and context layers. Ensure no residual doc claims --all covers the whole mailbox unconditionally.

---

### 824. Provide a sanctioned notmuch reindex remediation path for /email
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 823

**Description**: When staleness is detected (task 823) the skill currently dead-ends: notmuch new is treated as forbidden raw notmuch, so there is no sanctioned remediation. But notmuch new is index-only and non-mutating — exactly analogous to mbsync, which IS sanctioned via skill-email-sync (not a wrapper binary, passes mail-guard.sh, human-confirmed). Research how notmuch reindexing is actually wired for these maildirs (post-mbsync notmuch new hook? systemd path/timer? manual). Then add a sanctioned remediation mirroring the mbsync precedent: fold a reindex step into skill-email-sync or a documented /email --sync behavior, or document the exact sanctioned command, so the skill can remediate rather than dead-end. Reconcile wrapper-contracts.md §8 (two-layer enforcement) and mail-guard.sh reasoning to distinguish index-only notmuch new (sanctioned, like mbsync) from forbidden raw notmuch/himalaya MUTATION and tag commands; ensure skill MUST-NOT text stays consistent. May surface a .dotfiles handoff recommendation if reindex belongs in the frozen wrapper layer.

---

### 823. Add notmuch-staleness detection gate to skill-email-cleanup
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [823_email_notmuch_staleness_detection_gate/reports/01_staleness-detection-research.md]

**Description**: /email --all promises whole-mailbox coverage but classification reads notmuch (email-classify) while mailbox ground truth is maildir/himalaya (email-census); a stale notmuch index silently degrades --all to partial coverage (observed: census=62 vs notmuch folder:Logos=12 for the Logos INBOX). Add a wrapper-only staleness precondition to skill-email-cleanup that, before an --all sweep (and surfaced in default mode), compares the maildir ground-truth count from email-census against the notmuch indexed count for the same account/folder via the email-classify --limit 0 count-oracle (wrapper-contracts.md §10); on divergence beyond a small threshold, WARN or BLOCK with an actionable message rather than presenting partial coverage as whole-mailbox. Research must verify which source email-census actually counts from (maildir vs notmuch) so the comparison is meaningful. Add domain/staleness-detection.md documenting the check, count sources, and threshold. Wrapper-only compliant (both are wrapper calls); no .dotfiles change.

---

### 822. Implement email cleanup to memory vault contribution
- **Status**: [NOT STARTED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: Task 821

**Description**: Implement the email->memory contribution per the #821 design. Add a harvest step to skill-email-cleanup (or a memory lifecycle hook) that, when junk/keep decisions are confirmed, creates or UPDATEs a sender/domain-aggregated preference memory in the vault (CREATE/UPDATE/EXTEND with dedup against memory-index.json). Include an opt-in/gate consistent with skill-todo's harvest pattern, tests, and documentation updates to both extensions' READMEs/manifests.

---

### 821. Research and design email-to-memory contribution architecture
- **Status**: [RESEARCHED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [821_email_to_memory_contribution_architecture/reports/01_team-research.md]

**Description**: Route confirmed email-cleanup decisions (junk vs keep) from the email extension into the memory vault so the system learns sender/domain preferences over time. RESEARCH PHASE FIRST: survey July-2026 best practices for email-triage to preference/memory-learning systems (sender reputation, preference capture, vault-bloat avoidance, aggregation strategies, dedup, feedback loops), plus the concrete integration surfaces already identified: capture point = skill-email-cleanup human review gate (Stage 3 per-message / Stage 2.5 bucket approval in --all mode) where the JSONL candidate manifest (Message-ID keyed, proposed_action delete|archive|keep|unsure + confidence) is confirmed; memory API = skill-memory CREATE/UPDATE/EXTEND with content-mapping + MCP dedup against .memory/memory-index.json; reusable pattern = skill-todo's harvest->dedup->user-gated-create flow (Stage ~181+); hook surface = memory extension manifest.json empty hooks object as an alternative capture path. DESIGN DECISION ALREADY MADE BY USER: memories are SENDER/DOMAIN-AGGREGATED (one evolving preference memory per sender or domain, UPDATE/EXTEND as more mail is seen -- NOT per-message), chosen to avoid vault bloat; the research should refine the aggregation/dedup/schema mechanics within that decision, not relitigate it. Output: chosen capture point, memory schema/tags, dedup + update strategy, and opt-in/gate behavior.

---

### 820. Email all resurface classified gap
- **Effort**: 2 hours
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Dependencies**: None
- **Research**: [820_email_all_resurface_classified_gap/reports/01_wrapper-gap-seed.md]
- **Plan**: [820_email_all_resurface_classified_gap/plans/02_email-all-emit-tagged.md]
- **Summary**: [~/.dotfiles/modules/home/email/agent-tools/classify.nix]

**Description**: /email --all cannot re-surface an already-fully-classified mailbox for review: email-classify is emit-on-change, email-census takes no query, and mutation wrappers plan over an approved manifest not proposed-* tags, so there is no wrapper-only read-out of tagged messages. Fix spans the email extension skill (--all Stage 2) and the .dotfiles wrapper binaries (a read-only --emit-tagged / candidate rebuild). See reports/01_wrapper-gap-seed.md.

---

### 819. Load email extension in extensions json
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [819_load_email_extension_in_extensions_json/reports/01_intent-and-mechanics.md]
- **Plan**: [819_load_email_extension_in_extensions_json/plans/01_document-no-op-decision.md]

**Description**: Add the email extension to .claude/extensions.json so it is actually loaded and its EXTENSION.md content propagates into .claude/CLAUDE.md (pre-existing gap flagged in review-2026-07-04: check-extension-docs.sh warns 'routing target not deployed: skill-email-implementation', and EXTENSION.md->CLAUDE.md merge is unobservable because 'email' is absent from extensions.json). Only do this if the email extension is intended to be loaded in this repo. Verify: extension loads without routing warnings, EXTENSION.md [email] section propagates to CLAUDE.md via the merge mechanism.

---

### 818. Email extension doc consistency sweep
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Research**: [{]
- **Plan**: [818_email_extension_doc_consistency_sweep/plans/01_email-doc-consistency-sweep.md]

**Description**: Email/ extension documentation consistency sweep (findings 3,4,5,6 from review-2026-07-04). (3 MED) Finish account-generalizing archive-mode-risk.md: title still says 'All Mail Scope' (line 1), Blast-Radius table hardcodes ~64,000 msgs with no Logos row (12-17), Gate #1 hardcodes 'All Mail' (61), Gate #3 hardcodes 'mbsync gmail' (68) — make them match the account-generic tables in skill-email-cleanup/SKILL.md. (4 MED) Hardcode ONE pilot-ack file convention in skill-email-cleanup/SKILL.md (428-442) — single 'account'-keyed file with the gate always checking that path — instead of leaving it to per-invocation agent judgment. (5 MED) Refresh README.md (16-17,106-125): still describes /email as Gmail-only with no --account/--logos. (6 MED) Add a --sync channel/account mismatch warning in Stage 3 confirm (commands/email.md ~32-34, skill-email-sync/SKILL.md ~64-66). Ref: specs/reviews/review-2026-07-04.md.

---

### 817. Reconcile email stale multiaccount gating
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Topic**: extensions
- **Dependencies**: None
- **Plan**: [817_reconcile_email_stale_multiaccount_gating/plans/01_reconcile-multiaccount-gating.md]

**Description**: Reconcile the email/ extension's stale multi-account gating language with the now-verified wrapper contract. Ground truth: .dotfiles task 79 landed + switched in and was live-verified by .dotfiles task 80 (9/9 contract rows PASS), so wrapper-contracts.md is authoritative. Findings 1,2,7 from review-2026-07-04: (1 CRITICAL) strip the obsolete 'wrapper reserves --account gmail / hard error / pending task 79' gating language from commands/email.md (~41-44,67-72,204-208), EXTENSION.md (~29,72-77), skill-email-cleanup/SKILL.md (~45-60), skill-email-sync/SKILL.md (~58-61); (2 HIGH) convert the skill-email-cleanup precondition gate from a 'wrapper is gmail-only, STOP' gate into a light liveness check, and fix the probe: 'email-census --account logos --help' short-circuits before flag validation — use a real read-only probe like 'email-census --account logos' and check exit/stderr; (7 LOW) align gate naming ('step-1' vs 'Phase-1'). Ref: specs/reviews/review-2026-07-04.md. Verify: agent reading /email --logos gets one consistent, non-contradictory story; check-extension-docs.sh [email] still PASS.

---

### 87. Investigate terminal directory change when opening neovim in wezterm
- **Effort**: TBD
- **Status**: [RESEARCHED]
- **Task Type**: neovim
- **Topic**: Terminal UI
- **Dependencies**: None
- **Research**: [087_investigate_wezterm_terminal_directory_change/reports/research-001.md]

**Description**: Investigate why the terminal working directory changes to a project root when opening neovim sessions in wezterm from the home directory (~). Determine whether this behavior is caused by neovim or wezterm (configured in ~/.dotfiles/config/). Identify if any functionality depends on this behavior before modifying it. Goal is to avoid changing the terminal directory unless necessary.

---

### 78. Fix Himalaya SMTP authentication failure when sending emails
- **Effort**: 1-2 hours
- **Status**: [PLANNED]
- **Task Type**: neovim
- **Topic**: Email Integration
- **Dependencies**: None
- **Research**: [078_fix_himalaya_smtp_authentication_failure/reports/research-001.md]
- **Plan**: [078_fix_himalaya_smtp_authentication_failure/plans/implementation-001.md]

**Description**: Fix Gmail SMTP authentication failure when sending emails via Himalaya (<leader>me). Error: Authentication failed: Code: 535, Enhanced code: 5.7.8, Message: Username and Password not accepted. The error occurs with TLS connection attempts and persists through multiple retry attempts. Identify and fix the root cause of the SMTP credential configuration.
