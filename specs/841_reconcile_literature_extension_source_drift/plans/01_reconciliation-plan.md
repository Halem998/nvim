# Implementation Plan: Task #841

- **Task**: 841 - Reconcile literature extension source drift
- **Status**: [IMPLEMENTING]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/841_reconcile_literature_extension_source_drift/reports/01_drift-audit.md
- **Artifacts**: plans/01_reconciliation-plan.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The literature extension SOURCE OF TRUTH (`.claude/extensions/literature/scripts/`) has drifted
behind its DEPLOYED COPIES (`.claude/scripts/`): 6 files carry correctness fixes from tasks
#831/#833/#835/#839 that were never backported after the #793 migration. Because
`loader.lua`'s `copy_scripts()` overwrites deployed copies byte-for-byte from the extension
source on the next extension load/reload, those fixes will silently regress. This plan backports
the deployed content into the extension source (direction deployed→source only), adds the
deployed-only producer tool `literature-fidelity-audit.sh` to the extension source, installs a
content-diff drift guard in `check-extension-docs.sh`, and verifies every reconciled pair is
byte-identical. Definition of done: all 6 pairs (plus fidelity-audit) semantically equivalent,
guard demonstrably fails on artificial divergence, and fidelity-audit `--dry-run` classification
is byte-identical to a pre-task baseline.

### Research Integration

From `reports/01_drift-audit.md`:
- 6 files differ, direction unanimously deployed→extension-source with no conflicting
  extension-only edits (no STOP/report case): `literature-search.sh`, `literature-briefing.sh`,
  `literature-schema.sql`, `literature-chunk.sh`, `literature-convert.sh`, `literature-ingest.sh`.
- `literature-fidelity-audit.sh` is deployed-only and is the producer of the
  `unadjudicated`/`provenance_fidelity` markers that the (extension-owned) search/briefing scripts
  consume; it should be ADDED to the extension source and registered in `manifest.provides.scripts`.
- Guard: extend `check-extension-docs.sh` with a content-diff over `manifest.provides.scripts`
  entries (preferred over `.syncprotect`, which would freeze scripts against all future legitimate
  sync). Confirmed pre-task grep counts on deployed copies: `unadjudicated` = 2 (search) / 3
  (briefing); extension-source currently 0 / 0.
- Confirmed live regression mechanism: `copy_file()` is a plain byte-for-byte copy, no path
  substitution — so any current `diff` is genuine drift, and every reconciled pair must end
  byte-identical.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted (not provided in delegation context).

## Goals & Non-Goals

**Goals**:
- Backport the 6 drifted files deployed→extension-source so each reconciled pair is byte-identical.
- Add `literature-fidelity-audit.sh` to the extension source and register it in
  `manifest.provides.scripts`.
- Install a content-diff drift guard in `check-extension-docs.sh` that fails when a deployed script
  differs from its extension-source counterpart, and prove it fails on an injected divergence.
- Preserve exact runtime behavior of all deployed `.claude/scripts/` copies (no deployed edits).

**Non-Goals**:
- Modifying, re-deriving, or hand-editing any deployed `.claude/scripts/` copy. Backport is a
  verbatim copy deployed→source only; never source→deployed.
- Executing `literature-schema.sql` (or any reconciled script) against the live corpus DB
  (`~/Projects/Literature/.literature.db`). Only the extension-source *file* is edited.
- Fixing the opposite-direction, never-deployed gap (`zotero-*.sh`, `cite-extract.sh`,
  `test-lit-pipeline.sh` present only in extension source; `cite.md` never deployed). Noted as a
  follow-up only; the guard must NOT fail on these (absent deployed copy is not drift).
- Migrating other repo-local candidates (`literature-briefing-invoke.sh`,
  `literature-pyenv-provision.sh`, `zotero-resolve-pdf.sh`) into the extension.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Transcription error backporting the large `literature-convert.sh` (881 diff lines) | H | M | Copy the deployed file verbatim (`cp`), never hand-edit; re-run `diff` to confirm byte-identical (Phase 5a) |
| Schema backport misread as instruction to run DDL against live DB | H | L | Phase 2 edits the extension-source *file* only; explicit Non-Goal; no DB command in any phase |
| Adding fidelity-audit to `manifest.provides.scripts` makes the new guard flag it as a violation (no deployed diff expected, but sequencing) | M | M | Copy the deployed fidelity-audit verbatim into source BEFORE/at the same wave as the manifest edit; Phase 5 confirms guard treats it as in-sync |
| New guard fails on the 10 never-deployed extension-only scripts (absent deployed copy) | H | M | Guard fails ONLY when BOTH deployed and source copies exist and differ; absent deployed copy is skipped (documented in Phase 4) |
| A genuine extension-only edit is discovered mid-backport (unexpected per research) | M | L | Quarantine-never-delete; if any target has a real conflicting source edit, STOP and report rather than clobber |
| fidelity-audit `--dry-run` baseline not captured before edits | M | L | Phase 1 captures the baseline first; task adds/moves the file only and must not change its behavior |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 2, 3, 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Capture pre-task baselines [COMPLETED]

**Goal**: Record the desired end-state (deployed content) and the fidelity-audit behavioral
baseline before any edits, so Phase 5 can verify equivalence and no behavior change.

**Tasks**:
- [x] Capture `bash .claude/scripts/literature-fidelity-audit.sh --dry-run` full stdout to a
      baseline file (e.g. `specs/841_reconcile_literature_extension_source_drift/.baseline-fidelity-audit-dryrun.txt`). *(completed)*
- [x] Record `grep -c unadjudicated` on deployed `literature-search.sh` (expect 2) and
      `literature-briefing.sh` (expect 3); note both counts in the baseline file. *(completed: 2 and 3, matches expectation)*
- [x] Record `sha256sum` of each of the 6 deployed files
      (`literature-search.sh`, `literature-briefing.sh`, `literature-schema.sql`,
      `literature-chunk.sh`, `literature-convert.sh`, `literature-ingest.sh`) and the deployed
      `literature-fidelity-audit.sh`. *(completed)*
- [x] Confirm the current `diff` between each deployed/source pair is non-empty (drift still present). *(completed: all 6 show drift, fidelity-audit absent from source)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `specs/841_reconcile_literature_extension_source_drift/.baseline-fidelity-audit-dryrun.txt` - new baseline capture (task-local, not a source file)

**Verification**:
- Baseline file exists and contains the fidelity-audit `--dry-run` output plus the two grep counts (2 and 3) and seven sha256 sums.

---

### Phase 2: Backport the 6 drifted files deployed→extension-source [COMPLETED]

**Goal**: Make each of the 6 drifted extension-source files byte-identical to its deployed copy
via verbatim copy.

**Tasks**:
- [x] For each of the 6 files, copy the deployed `.claude/scripts/<name>` verbatim over
      `.claude/extensions/literature/scripts/<name>` (`cp`, not hand-edit / re-derive):
      `literature-search.sh`, `literature-briefing.sh`, `literature-schema.sql`,
      `literature-chunk.sh`, `literature-convert.sh`, `literature-ingest.sh`. *(completed)*
- [x] After each copy, run `diff .claude/scripts/<name> .claude/extensions/literature/scripts/<name>`
      and confirm empty output. *(completed: all 6 identical)*
- [x] Do NOT touch any deployed copy; do NOT execute the schema file against any DB. *(completed: `git status --porcelain -- .claude/scripts/` empty)*
- [x] If any target reveals a genuine conflicting extension-only edit (not expected per research),
      STOP and report rather than clobber (quarantine-never-delete posture). *(completed: pre-copy diff review of schema/chunk/ingest confirmed unanimous deployed-ahead direction with task-numbered fixes; no extension-only content found)*

**Timing**: 40 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/literature/scripts/literature-search.sh` - overwrite with deployed content
- `.claude/extensions/literature/scripts/literature-briefing.sh` - overwrite with deployed content
- `.claude/extensions/literature/scripts/literature-schema.sql` - overwrite with deployed content
- `.claude/extensions/literature/scripts/literature-chunk.sh` - overwrite with deployed content
- `.claude/extensions/literature/scripts/literature-convert.sh` - overwrite with deployed content
- `.claude/extensions/literature/scripts/literature-ingest.sh` - overwrite with deployed content

**Verification**:
- `diff` on all 6 pairs produces no output (byte-identical).

---

### Phase 3: Add literature-fidelity-audit.sh to extension source + register in manifest [NOT STARTED]

**Goal**: Ship the fidelity/provenance producer tool in the extension source alongside its
consumers, and declare it in the manifest.

**Tasks**:
- [ ] Copy deployed `.claude/scripts/literature-fidelity-audit.sh` verbatim to
      `.claude/extensions/literature/scripts/literature-fidelity-audit.sh` (`cp`).
- [ ] Add `"literature-fidelity-audit.sh"` to `.claude/extensions/literature/manifest.json`
      `provides.scripts` (keep JSON valid; place consistently with existing ordering).
- [ ] Confirm `diff` on the fidelity-audit pair is empty and `jq empty` accepts the edited manifest.

**Timing**: 25 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/literature/scripts/literature-fidelity-audit.sh` - new file (verbatim deployed copy)
- `.claude/extensions/literature/manifest.json` - add `literature-fidelity-audit.sh` to `provides.scripts`

**Verification**:
- `diff .claude/scripts/literature-fidelity-audit.sh .claude/extensions/literature/scripts/literature-fidelity-audit.sh` is empty.
- `jq -e '.provides.scripts | index("literature-fidelity-audit.sh")' .claude/extensions/literature/manifest.json` returns a non-null index.

---

### Phase 4: Implement the drift guard in check-extension-docs.sh [NOT STARTED]

**Goal**: Add a content-diff check that fails when a `manifest.provides.scripts` entry's deployed
copy differs from its extension-source copy, without false-failing on never-deployed scripts.

**Tasks**:
- [ ] Add a new per-extension function (e.g. `check_deployed_script_drift`) that iterates
      `.provides.scripts` and, for each entry where BOTH `$REPO_ROOT/.claude/scripts/<name>` and
      `$ext_path/scripts/<name>` exist, runs `cmp -s` and calls `fail` on any difference.
- [ ] Skip (no fail) when the deployed copy is ABSENT — that is the opposite-direction
      never-deployed gap (`zotero-*`, `cite-extract.sh`, `test-lit-pipeline.sh`), explicitly out of
      scope; optionally emit an `info`/WARN note.
- [ ] Wire the new function into the main per-extension loop next to the other `check_*` calls
      (guarded by the existing valid-manifest branch).
- [ ] Match the existing exit-code contract (0 pass / 1 fail) and `fail`/`info` helpers.

**Timing**: 35 minutes

**Depends on**: 2, 3

**Files to modify**:
- `.claude/scripts/check-extension-docs.sh` - add `check_deployed_script_drift` and call it in the main loop

**Verification**:
- `bash .claude/scripts/check-extension-docs.sh` exits 0 (PASS) now that Phases 2-3 made all
  present pairs in-sync, and does NOT fail on the never-deployed extension-only scripts.

---

### Phase 5: Verification [NOT STARTED]

**Goal**: Prove equivalence, correct marker counts, a working guard, and unchanged fidelity-audit
behavior.

**Tasks**:
- [ ] (a) `diff` each of the 7 reconciled pairs (6 drifted + fidelity-audit) → confirm no differences.
- [ ] (b) `grep -c unadjudicated` on extension-source `literature-search.sh` (expect 2) and
      `literature-briefing.sh` (expect 3); confirm they now match the Phase 1 deployed counts.
- [ ] (c) Guard must FAIL on divergence: temporarily inject a trivial change into one
      extension-source script, run `bash .claude/scripts/check-extension-docs.sh`, confirm non-zero
      exit with a drift FAIL for that file, then revert the injection and confirm PASS again.
- [ ] (d) Run `bash .claude/scripts/literature-fidelity-audit.sh --dry-run` and confirm its output
      is byte-identical to the Phase 1 baseline (`diff` against the baseline file).
- [ ] Run the full `check-extension-docs.sh` once more → PASS with no drift failures.

**Timing**: 30 minutes

**Depends on**: 2, 3, 4

**Files to modify**:
- (none — verification only; any temporary injection in task (c) is reverted)

**Verification**:
- All of (a)-(d) pass; full doc-lint exits 0.

---

## Testing & Validation

- [ ] All 7 reconciled pairs are byte-identical (`diff` empty).
- [ ] Extension-source `unadjudicated` counts: search = 2, briefing = 3 (match deployed baseline).
- [ ] `check-extension-docs.sh` exits 0 after reconciliation and does not fail on never-deployed scripts.
- [ ] Guard exits non-zero when an artificial divergence is injected (then reverts to PASS).
- [ ] `literature-fidelity-audit.sh --dry-run` output byte-identical to pre-task baseline.
- [ ] No deployed `.claude/scripts/` file modified (compare against Phase 1 sha256 sums).

## Artifacts & Outputs

- `plans/01_reconciliation-plan.md` (this file)
- `.claude/extensions/literature/scripts/{literature-search,literature-briefing,literature-chunk,literature-convert,literature-ingest}.sh` (reconciled)
- `.claude/extensions/literature/scripts/literature-schema.sql` (reconciled)
- `.claude/extensions/literature/scripts/literature-fidelity-audit.sh` (added)
- `.claude/extensions/literature/manifest.json` (fidelity-audit registered)
- `.claude/scripts/check-extension-docs.sh` (drift guard added)
- `summaries/01_reconciliation-summary.md` (on completion)

## Rollback/Contingency

- All changes are confined to the extension source, the manifest, and the doc-lint script — none
  touch deployed runtime copies, so runtime behavior cannot regress from this task.
- If a genuine conflict is discovered during Phase 2/3, STOP and report; leave that file untouched
  (quarantine-never-delete) and complete the remaining non-conflicting files.
- To revert: `git checkout` the modified extension-source files, `manifest.json`, and
  `check-extension-docs.sh`; the deployed copies and live corpus DB are never touched.
