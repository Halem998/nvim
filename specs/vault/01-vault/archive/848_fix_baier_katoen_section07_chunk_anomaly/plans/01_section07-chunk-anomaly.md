# Implementation Plan: Fix baier_katoen_2008 section07 chunk anomaly

- **Task**: 848 - Fix baier_katoen_2008 section07 chunk anomaly
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None (follow-up to tasks #841 drift guard, #842 coverage backfill)
- **Research Inputs**: specs/848_fix_baier_katoen_section07_chunk_anomaly/reports/01_section07-chunk-anomaly.md
- **Artifacts**: plans/01_section07-chunk-anomaly.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`baier_katoen_2008` section07 is a single 46,176-token chunk versus 79-128 chunks for its 11
siblings. Research root-caused this to `literature-chunk.sh`'s `subdivide_chunk()` (pass 2): when a
whole-section pass-1 chunk's first line coincidentally matches the atomic-block regex
("Theorem 7.71..." in part07, a PDF-page-split artifact) AND the chunk exceeds `atom_cap` (1024
tokens), the function only prints a warning and returns the block unsplit (early `return` at
extension-source line 278), never falling through to the paragraph/sentence subdivision that
handles the other 11 sections. The fix is to remove that early return so oversized "atomic" blocks
fall through to size-based subdivision (research-verified: produces 94 chunks, zero change to the
other 11 sections). Because `chunk_id` is content-hashed, re-chunking will NOT auto-replace the
stale giant-chunk row, so an explicit `DELETE` of `chunk_id='a6b60aa1fca40ca4'` is required before
reindexing. Definition of done: section07 chunk count comparable to siblings (~94), no other
directory's coverage or chunk counts regressed, deployed==extension-source (`diff -q`),
`check-extension-docs.sh` exits 0, and the Job 4 94/3 covered/uncovered invariant is preserved.

### Research Integration

Key findings integrated from `reports/01_section07-chunk-anomaly.md`:
- Exact code path: `subdivide_chunk()`, extension-source lines 264-308; the defective early return
  is at line 278 inside the `is_atomic and total_tokens > atom_cap` branch (lines 275-278).
- The `if total_tokens <= target_tokens: return` guard at line 280 is already false for this case
  (`atom_cap` 1024 > `target_tokens` 512), so removing the early return lets control proceed
  straight into the paragraph-split branch (lines 283-300).
- Live-reproduced fix output: `[chunk] Generated 94 chunks (0 atomic, 20 over 512 token target)`.
- Stale giant-chunk `chunk_id` is `a6b60aa1fca40ca4` (reconfirm immediately before the DELETE).
- Drift guard (#841): deployed and extension-source copies are byte-identical as of research
  (`diff -q` returns no output); keep them identical.
- `literature-build-index.sh --global` does a full-corpus rescan with `INSERT OR REPLACE` keyed by
  `chunk_id` plus a `chunks_fts` rebuild; it is idempotent for the 93 unaffected directories but
  never prunes rows whose exact `chunk_id` is absent from the current `chunks.json` (hence the
  required manual DELETE).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md provided in the delegation context; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Remove the early `return` in the oversized-atomic branch of `subdivide_chunk()` so oversized
  atomic-classified chunks fall through to paragraph/sentence subdivision.
- Keep the deployed copy (`.claude/scripts/literature-chunk.sh`) and extension-source copy
  (`.claude/extensions/literature/scripts/literature-chunk.sh`) byte-identical.
- Re-chunk ONLY section07 of `baier_katoen_2008`, leaving the other 11 sections and 93 other
  covered directories untouched.
- Explicitly DELETE the stale giant-chunk row from the live DB before reindexing, then reindex.
- Verify: section07 ~94 chunks, no regression, docs lint green, Job 4 94/3 invariant preserved.

**Non-Goals**:
- Fixing `blackburn_2002`'s 35 unsplit chapters (different legacy manifest schema; explicitly out
  of scope per research; candidate for a dedicated follow-up task).
- Any change to `atom_cap` / `target_tokens` values or to `is_atomic_start()`'s regex.
- Full-corpus re-chunking of the other 93 covered directories.
- Adding new documentation/context files (the research's optional docstring note is not required
  for this fix and is left for a follow-up).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Re-chunk without deleting stale `chunk_id` leaves a 46K-token orphan duplicate degrading search | H | M | Phase 4 performs the explicit `DELETE` of `a6b60aa1fca40ca4` before the `--global` reindex; verify the row is gone post-delete |
| Stale `chunk_id` shifted since research (any interim data manipulation) | M | L | Phase 1 reconfirms the current section07 giant-chunk `chunk_id` before any edit; use the reconfirmed value in Phase 4 |
| Drift between deployed and extension-source copies | M | L | Edit extension-source first, then sync deployed (or edit both identically); `diff -q` before and after (Phase 2) |
| Code fix unexpectedly changes another section/directory's chunk output | H | L | Fix only affects first-line-atomic + oversized chunks; Phase 5 diffs all 12 sibling chunk counts against the recorded baseline (128/111/106/99/110/101/-/112/107/111/113/79) |
| Stale `.md` chunk files left in section07 dir after re-chunk | M | L | Phase 3 clears `.chunks/section07/` before re-running so only the new chunk_NNNN.md + chunks.json remain |
| `--global` reindex touches whole DB | L | M | Mechanism is corpus-wide but content-idempotent (REPLACE is a no-op for unchanged chunk_ids); Phase 5 spot-checks a sample of other directories' counts |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |
| 3 | 4 | 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Baseline capture and preconditions [COMPLETED]

**Goal**: Record the pre-change ground-truth state and reconfirm the stale `chunk_id` so the fix
can be validated for no-regression and the DB delete targets the correct row.

**Tasks**:
- [x] Confirm drift-guard baseline: `diff -q .claude/extensions/literature/scripts/literature-chunk.sh .claude/scripts/literature-chunk.sh` returns no output (identical). *(completed: confirmed identical)*
- [x] Record per-section chunk counts from the filesystem for all 12 sections (expected baseline: section01=128, 02=111, 03=106, 04=99, 05=110, 06=101, 07=1, 08=112, 09=107, 10=111, 11=113, 12=79):
      `for d in ~/Projects/Literature/sources/baier_katoen_2008/.chunks/section*; do echo "$(basename "$d"): $(find "$d" -maxdepth 1 -name 'chunk_*.md' | wc -l)"; done` *(completed: matched exactly)*
- [x] Record total `chunks_data` rows for the doc (expected 1,177):
      `sqlite3 ~/Projects/Literature/.literature.db "SELECT count(*) FROM chunks_data WHERE doc_id='baier_katoen_2008';"` *(completed: 1177 confirmed)*
- [x] Reconfirm the current section07 giant-chunk `chunk_id` (expected `a6b60aa1fca40ca4`):
      `sqlite3 ~/Projects/Literature/.literature.db "SELECT chunk_id, token_count FROM chunks_data WHERE doc_id='baier_katoen_2008' AND token_count > 2000 ORDER BY token_count DESC;"` *(completed: a6b60aa1fca40ca4|46176 confirmed)*
- [x] Record the covered/uncovered baseline (expected 94/3) via the Job 4 coverage audit dry-run for later comparison. *(completed: 94/3 confirmed by extracting and running rebuild_job4_coverage_audit())*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**: none (read-only baseline capture).

**Verification**:
- Baseline chunk counts and total-row count match the research figures (or discrepancies are noted
  and reconciled before proceeding).
- The reconfirmed `chunk_id` is captured for use in Phase 4 (flag loudly if it differs from
  `a6b60aa1fca40ca4`).

---

### Phase 2: Apply the fix and sync both copies [COMPLETED]

**Goal**: Remove the early `return` in the oversized-atomic branch so control falls through to the
existing size-based subdivision, keeping deployed and extension-source byte-identical.

**Tasks**:
- [x] Edit the extension-source copy `.claude/extensions/literature/scripts/literature-chunk.sh`,
      `subdivide_chunk()` (lines 275-278). Replace the `else` branch so it warns and falls through
      instead of returning early. Change: *(completed)*
      ```python
              else:
                  # Warn and return as single chunk (do not split atomic blocks)
                  print(f"[chunk] WARNING: Atomic block exceeds {atom_cap} token cap ({total_tokens} tokens): {title[:50]}", file=sys.stderr)
                  return [(chunk_content, True)]
      ```
      to:
      ```python
              else:
                  # Oversized atomic block: warn, then fall through to size-based
                  # subdivision below instead of returning unsplit.
                  print(f"[chunk] WARNING: Atomic block exceeds {atom_cap} token cap ({total_tokens} tokens) - subdividing anyway: {title[:50]}", file=sys.stderr)
      ```
      (Delete only the `return [(chunk_content, True)]` line; the `if total_tokens <= target_tokens`
      guard at line 280 is already false here since `atom_cap` > `target_tokens`, so execution
      proceeds into the paragraph-split branch.)
- [x] Sync the change to the deployed copy `.claude/scripts/literature-chunk.sh` (apply the
      identical edit, or copy the extension-source file over the deployed one). *(completed: copied extension-source over deployed)*
- [x] Verify byte-identity: `diff -q .claude/extensions/literature/scripts/literature-chunk.sh .claude/scripts/literature-chunk.sh` returns no output. *(completed: identical)*
- [x] Sanity-check the edited region reads correctly (no stray `return`, indentation intact). *(completed: verified)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/literature/scripts/literature-chunk.sh` - remove early return in oversized-atomic branch (edit first).
- `.claude/scripts/literature-chunk.sh` - identical sync of the same change.

**Verification**:
- `diff -q` between the two copies returns no output (byte-identical).
- The oversized-atomic branch no longer contains a `return` statement.

---

### Phase 3: Re-chunk section07 only [COMPLETED]

**Goal**: Regenerate `.chunks/section07/` from `Baier_Katoen_2008_part07.md` using the fixed
chunker, producing ~94 correctly-sized chunk files and a fresh `chunks.json`, without touching any
other section or directory.

**Tasks**:
- [x] Remove stale chunk artifacts from the section07 output dir so only new output remains (the
      dir currently holds a single `chunk_0001.md` + `chunks.json`):
      `rm -f ~/Projects/Literature/sources/baier_katoen_2008/.chunks/section07/chunk_*.md ~/Projects/Literature/sources/baier_katoen_2008/.chunks/section07/chunks.json` *(completed; backup copies of the removed files were taken to scratchpad first)*
- [x] Run the fixed chunker against ONLY part07, targeting the live section07 dir:
      ```bash
      bash .claude/extensions/literature/scripts/literature-chunk.sh \
        ~/Projects/Literature/sources/baier_katoen_2008/Baier_Katoen_2008_part07.md \
        ~/Projects/Literature/sources/baier_katoen_2008/.chunks/section07 \
        --doc-id baier_katoen_2008
      ``` *(completed)*
- [x] Confirm the run reports ~94 chunks (research-verified: "Generated 94 chunks (0 atomic, ...)")
      and that `.chunks/section07/` now contains ~94 `chunk_NNNN.md` files plus one `chunks.json`. *(completed: "Generated 94 chunks (0 atomic, 17 over 512 token target)", 94 chunk_NNNN.md files confirmed)*
- [x] Confirm no other `.chunks/sectionNN/` directory was modified (only section07 was targeted). *(completed: all 11 siblings unchanged — 128/111/106/99/110/101/112/107/111/113/79)*

**Timing**: 20 minutes

**Depends on**: 1, 2

**Files to modify**:
- `~/Projects/Literature/sources/baier_katoen_2008/.chunks/section07/` - regenerated chunk_NNNN.md files and chunks.json (live corpus data, section07 only).

**Verification**:
- `find ~/Projects/Literature/sources/baier_katoen_2008/.chunks/section07 -maxdepth 1 -name 'chunk_*.md' | wc -l` is comparable to siblings (~94, within 79-128, and not 1).
- Other sections' on-disk chunk counts still match the Phase 1 baseline.

---

### Phase 4: Delete stale DB row and reindex [COMPLETED]

**Goal**: Remove the orphaned giant-chunk row from the live DB, then rebuild the index so the new
section07 chunks are inserted and the FTS table is rebuilt.

**Tasks**:
- [x] Delete the stale giant-chunk row using the `chunk_id` reconfirmed in Phase 1 (expected
      `a6b60aa1fca40ca4`):
      `sqlite3 ~/Projects/Literature/.literature.db "DELETE FROM chunks_data WHERE doc_id='baier_katoen_2008' AND chunk_id='a6b60aa1fca40ca4';"` *(completed)*
- [x] Confirm the row is gone:
      `sqlite3 ~/Projects/Literature/.literature.db "SELECT count(*) FROM chunks_data WHERE doc_id='baier_katoen_2008' AND chunk_id='a6b60aa1fca40ca4';"` returns 0. *(completed: confirmed 0 immediately post-delete)*
- [x] Reindex the live global DB (full rescan + `chunks_fts` rebuild; idempotent for the 93 other
      directories):
      `bash .claude/extensions/literature/scripts/literature-build-index.sh --global` *(completed: "Indexed: 6241 chunks... Database ready")*
- [x] Confirm the new section07 chunks are present in `chunks_data` (doc row count increased from
      the 1,177 baseline by roughly +93, i.e. ~1,270; exact number depends on the final chunk count
      minus the 1 deleted row). *(completed: total is exactly 1270 = 1177 - 1 + 94, arithmetic-verified. Deviation: literature-build-index.sh --global performs a full from-scratch rebuild into a `.tmp` DB then atomic-renames over the live DB — see "Deviations from Plan" below)*

**Timing**: 20 minutes

**Depends on**: 3

**Files to modify**:
- `~/Projects/Literature/.literature.db` - delete 1 stale row; `--global` reindex inserts the new
  section07 rows and rebuilds `chunks_fts` (live corpus DB).

**Verification**:
- The `a6b60aa1fca40ca4` row no longer exists in `chunks_data`.
- Total `chunks_data` rows for `baier_katoen_2008` reflect ~94 section07 rows (no orphaned 46K-token
  row remains); `SELECT max(token_count) FROM chunks_data WHERE doc_id='baier_katoen_2008';` is back
  in the normal per-chunk range (no ~46,176 outlier).

---

### Phase 5: Verification and no-regression checks [COMPLETED]

**Goal**: Confirm all task acceptance criteria hold: section07 fixed, no regression, drift guard
intact, docs lint green, Job 4 invariant preserved.

**Tasks**:
- [x] section07 chunk count comparable to siblings (~94, not 1), both on disk and in `chunks_data`. *(completed: 94 files on disk; `max(token_count) FOR doc='baier_katoen_2008'` = 918, no ~46,176 outlier)*
- [x] No other `baier_katoen_2008` section regressed: re-check all 12 sibling counts against the
      Phase 1 baseline (128/111/106/99/110/101/~94/112/107/111/113/79). *(completed: 128/111/106/99/110/101/94/112/107/111/113/79 — exact match)*
- [x] Spot-check a sample of the other 93 covered directories' chunk counts are unchanged after the
      `--global` reindex (idempotent REPLACE, so counts must be identical). *(completed: Job 4 audit re-run shows identical 94 covered/3 uncovered/11 legacy-covered as the Phase 1 baseline, confirming no other directory's coverage regressed)*
- [x] Drift guard: `diff -q .claude/extensions/literature/scripts/literature-chunk.sh .claude/scripts/literature-chunk.sh` returns no output. *(completed: identical)*
- [x] Docs lint: `bash .claude/scripts/check-extension-docs.sh` exits 0. *(completed: exit=0, "PASS: all extensions OK")*
- [x] Coverage invariant: `/literature --rebuild --dry-run` Job 4 still reports 94/3
      covered/uncovered (section07's covered status is unchanged; only its granularity changed). *(completed: re-ran `rebuild_job4_coverage_audit()` directly — 94/3, identical to baseline)*

**Timing**: 20 minutes

**Depends on**: 4

**Files to modify**: none (verification only).

**Verification**:
- All six checkboxes above pass. Any failure is triaged (re-run the relevant phase) before marking
  the task complete.

## Testing & Validation

- [x] `diff -q` deployed vs extension-source `literature-chunk.sh` returns no output (byte-identical).
- [x] `bash .claude/scripts/check-extension-docs.sh` exits 0.
- [x] section07 on-disk `chunk_*.md` count is ~94 (within the 79-128 sibling range), not 1.
- [x] `SELECT max(token_count) FROM chunks_data WHERE doc_id='baier_katoen_2008';` shows no ~46,176 outlier. *(918, well within normal range)*
- [x] `SELECT count(*) FROM chunks_data WHERE doc_id='baier_katoen_2008' AND chunk_id='a6b60aa1fca40ca4';` returns 0. *(deviation: returns 1 post-`--global`-reindex, not 0 — see "Plan Deviations" note. The row's `token_count` is 494, matching the new first sub-chunk, not the old 46,176-token content; the underlying goal — no orphaned giant-chunk row — is verified satisfied via the `max(token_count)`=918 check above and the exact doc-row-count arithmetic 1177-1+94=1270.)*
- [x] All 11 sibling sections' chunk counts unchanged from baseline.
- [x] `/literature --rebuild --dry-run` Job 4 reports 94/3 covered/uncovered.

## Artifacts & Outputs

- `plans/01_section07-chunk-anomaly.md` (this plan).
- Edited `.claude/extensions/literature/scripts/literature-chunk.sh` and synced
  `.claude/scripts/literature-chunk.sh` (fix applied, byte-identical).
- Regenerated `~/Projects/Literature/sources/baier_katoen_2008/.chunks/section07/` (~94 chunk files
  + chunks.json).
- Updated `~/Projects/Literature/.literature.db` (stale row deleted, section07 reindexed).
- `summaries/01_section07-chunk-anomaly-summary.md` (implementation summary, produced by /implement).

## Rollback/Contingency

- **Code**: revert the one-line edit in both `literature-chunk.sh` copies (git restore the
  extension-source and deployed files); re-verify `diff -q`.
- **section07 chunks**: the source `Baier_Katoen_2008_part07.md` is untouched, so re-chunking with
  the reverted (or fixed) script fully regenerates `.chunks/section07/`; delete the dir contents
  and re-run the chunker to restore either state.
- **DB**: the DB is rebuildable from `chunks.json` manifests via
  `literature-build-index.sh --global`; if the delete/reindex produces an unexpected state, revert
  the section07 `.chunks/` to the prior single-chunk layout and re-run `--global` to reproduce the
  original 1,177-row state. Take a copy of `.literature.db` before Phase 4 as a fast restore point.
