# Implementation Plan: Fix validate directory-path false positives and flag mismatch

- **Task**: 71 - Fix validate-mode directory-path false positives and normalize-authors flag mismatch
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: None (sequenced after the conversion quality-gate hardening in
  `specs/069_harden_conversion_quality_gate_against_mojibake/`, which research confirmed does
  not interact with validate mode)
- **Research Inputs**: `specs/071_fix_validate_directory_path_false_positives_and_flag_mismatch/reports/01_validate-false-positives-flag-mismatch.md`
- **Artifacts**: plans/01_validate-dirpath-flag-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two low-severity defects in the literature extension's `/literature --validate` path. Defect 1:
Validate Step 2 tests every indexed entry with `[ ! -f "$full_path" ]`, which is false for the
directory-path schema variant used by book/parent-level entries, so every such entry is reported
stale even though it exists — and, because the recount/schema/authors checks all live in the
`else` branch, those entries also silently escape schema and authors-shape validation entirely.
Defect 2: the Validate Step 4 report template tells the user to pass `--dry-run` to
`literature-normalize-authors.sh`, a flag that script hard-rejects with `Unknown argument` and
exit 1. Both fixes are confined to the source store; done means validate reports zero
false-positive stale entries against the live global index, directory entries are schema-checked,
and no documented invocation of the normalize script fails.

### Research Integration

The research report reproduced both defects against the current source tree and the live global
index at `~/Projects/Literature/index.json`, and established four facts this plan builds on:

1. Directory-path entries (trailing `/`, `doc_type: "book"`, `token_count: 0`) are a legitimate
   second schema variant, not malformed records. All directory-path entries checked in the live
   index exist on disk; zero files are genuinely missing, making the current stale report a 100%
   false positive.
2. Directory entries have no single content file, so the token-drift recount cannot apply to
   them; existence checking is the correct and sufficient check for that variant.
3. The `jq`-driven schema-field and authors-shape checks read `index.json`, not the filesystem,
   so they can and should run for directory entries once the branch is restructured.
4. `.md.rejected` / `.md.bak-*` quarantine artifacts produced by the conversion quality-gate
   hardening are invisible to both the stale check (only indexed paths are iterated) and the
   unindexed-file scan (`find -name "*.md"` does not match them). No re-baselining or
   quarantine-aware handling is required by this task.

The research recommended a doc-only fix for Defect 2 and explicitly argued against adding a
`--dry-run` alias. This plan does the doc fix as the authoritative correction (Phase 2, step 1)
and additionally adds the alias (Phase 2, step 2) on evidence the research did not weigh: two
sibling scripts in the same directory — `literature-repair-combining.sh` and `zotero-write.sh` —
already accept an explicit `--dry-run`, so the current hard-fail is an inconsistency within the
script family, and a no-op alias makes the natural invocation safe independently of future doc
drift. If the implementer finds the alias creates any ambiguity in `usage()` output, the doc fix
alone closes the defect and the alias may be dropped with a recorded reason.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No open `specs/ROADMAP.md` item is advanced by this task. The nearest item, **Literature
centralization**, is already marked complete; this is defect maintenance on tooling that item
delivered, not new roadmap scope.

## Goals & Non-Goals

**Goals**:
- Validate Step 2 correctly distinguishes directory-path entries from file-path entries and
  reports a directory entry stale only when the directory genuinely does not exist.
- Directory-path entries receive the same `jq`-driven schema-field and authors-shape validation
  that file-path entries already receive.
- The Step 2 prose preamble accurately describes which checks apply to which path variant.
- Every invocation of `literature-normalize-authors.sh` named in the Validate Step 4 report
  template succeeds.
- All edits land in `agent-system/extensions/literature/**`, never `.claude/**`.

**Non-Goals**:
- Re-baselining `token_count` across the corpus (Adjacent Finding A). Research established this
  is independent of the quality-gate hardening and is a separate scheduling decision.
- Correcting the `sources/diamondsareforever/chunk_0001.md` record's legacy `chunks_dir` /
  current `path` schema co-mingling (Adjacent Finding B). This is a data-correctness question —
  which of `token_count: 95000` and the 903-byte chunk path is authoritative — not a
  validate-logic bug, and a validate fix must not paper over it by special-casing `chunks_dir`.
- Any aggregate token accounting for directory entries (e.g. summing chunk files under a book
  directory). Existence-only is the correct check for this variant.
- Changing the `authors`-shape heuristic, the index schema, or any conversion/chunking script.
- Creating follow-up tasks for the deferred adjacent findings. They are recorded in the
  implementation summary for the team lead to schedule.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The `-d` branch is written so loosely it stops detecting a genuinely deleted book directory | H | M | Keep an explicit `[ -d "$full_path" ]` existence assertion in the directory branch; a failing directory MUST still land in `stale_entries`. Phase 3 verifies by pointing the loop at a deliberately non-existent directory path. |
| Restructuring the branch accidentally drops schema/authors checks for file entries | M | M | Phase 3 runs the extracted block against the live index and compares warning counts for file-path entries against a pre-change baseline captured in Phase 1. |
| Edits land in `.claude/skills/skill-literature/SKILL.md` (the deployed copy) instead of the source store | M | M | Phase 3 asserts `git status` shows no `.claude/**` modifications; the advisory PostToolUse hook also fires on such a write. |
| Adding a `--dry-run` alias diverges the script from its own header documentation | L | M | Update the header comment block, the `Usage:` line, and `usage()` in the same edit so all three agree. |
| The live global index is concurrently modified by other work, making counts unstable | L | M | Treat every entry count as a Scope Hypothesis confirmed at implementation time, never as a fixed number copied from the report. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. Phases 1 and 2 both edit
`SKILL.md` and are deliberately sequenced rather than parallelized to avoid concurrent edits to
the same file.

---

### Phase 1: Fix directory-path branching in Validate Step 2 [COMPLETED]

**Goal**: Validate Step 2 handles both path schema variants correctly — directory entries are
existence-checked and schema/authors-checked, file entries keep their existing behavior
unchanged including the token-drift recount.

**Tasks**:
- [x] Capture a pre-change baseline: extract the current Validate Step 2 bash block to a scratch
      script, run it against `~/Projects/Literature/index.json`, and record the counts of
      `stale_entries`, `drift_entries`, `schema_warnings`, and `authors_shape_warnings`. *(completed: baseline 369 entries -- stale=80, drift=56, schema_warnings=35, authors_shape_warnings=53)*
- [x] Replace the two-way `if [ ! -f ... ]; then ... else ... fi` with a three-way branch:
      directory-path entries (`[[ "$entry_path" == */ ]] || [ -d "$full_path" ]`), missing
      file-path entries, and existing file-path entries. *(completed)*
- [x] In the directory branch, assert existence with `[ -d "$full_path" ]` and push
      `"$entry_path (missing directory)"` into `stale_entries` when it fails. Do not attempt a
      token recount for this variant. *(completed: verified with a fabricated non-existent directory entry)*
- [x] Hoist the two `jq`-driven checks (required-schema-fields and authors-shape) out of the
      file-only branch so they run for every entry that resolves on disk, directory entries
      included. Leave both `jq` programs byte-identical — this phase relocates them, it does not
      rewrite them. *(completed: jq programs byte-identical, only relocated)*
- [x] Update the Step 2 prose preamble's numbered list so item 1 reads as existence checking
      (`-f` for file paths, `-d` for directory paths) and item 2 states that token-drift
      recounting applies to file-path entries only. *(completed)*
- [x] Add a short comment in the bash block naming the directory-path variant
      (`doc_type: "book"`, parent record for a chunked book, `token_count: 0` by design) so the
      branch is not later "simplified" back into the bug. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The research counted 34 directory-path entries in the live global index,
all existing on disk, and zero genuinely-missing files across all entries. Both numbers are
hypotheses, not facts — the corpus is under concurrent modification. Confirm at implementation
time with a direct loop over `jq -r '.entries[].path'` classifying each path by
`-d`/`-f`/neither, and record the observed counts in the summary rather than restating the
report's.

**Files to modify**:
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` - Validate Step 2: the
  prose preamble's numbered check list and the `stale_entries` bash block's branch structure.

**Verification**:
- Extract the edited block to a scratch script and run it against `~/Projects/Literature/index.json`.
- `stale_entries` contains zero directory-path entries.
- `drift_entries`, and the file-path subset of `schema_warnings` / `authors_shape_warnings`,
  match the Phase 1 pre-change baseline exactly.
- `schema_warnings` / `authors_shape_warnings` now include directory-path entries in their
  coverage (verified by instrumenting the loop to count entries reaching each check, not by
  assuming a warning will fire).
- Inject a fabricated index entry pointing at a non-existent directory path and confirm it is
  still reported stale.

---

### Phase 2: Correct the normalize-authors invocation contract [COMPLETED]

**Goal**: No invocation of `literature-normalize-authors.sh` named in documentation fails, and
the script's accepted-flag surface is consistent with its sibling scripts.

**Tasks**:
- [x] Reword the Validate Step 4 "Authors Shape Warnings" template sentence to stop naming a
      `--dry-run` flag as the preview mechanism; state that omitting the flag is the default and
      previews the change (e.g. "run with no flag — dry-run is the default — to preview first"). *(completed)*
- [x] Add `--dry-run` as an explicit no-op alias in the script's argument-parsing `case`
      (alongside the existing `--apply|--write` branch), so the natural invocation exits 0 in
      preview mode rather than hard-failing with `Unknown argument`. *(completed)*
- [x] Update the script's `usage()` output and its header `Usage:` / mode-description comment
      block so all three sites describe the same flag surface. Do not change the default
      behavior: bare invocation remains dry-run. *(completed)*
- [x] Grep the repository for every other reference to `literature-normalize-authors.sh` and
      confirm none documents a flag the script does not accept. *(completed: grep of agent-system/ and specs/ found only the fixed SKILL.md site and archived/informational task artifacts in specs/**, none documenting an unsupported flag)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: The Validate Step 4 report template is believed to be the only in-repo
site documenting a `--dry-run` invocation of this script. Confirm with
`grep -rn 'literature-normalize-authors' agent-system/ specs/` before declaring the phase done;
if additional sites exist, fix them in this phase or record them explicitly.

**Files to modify**:
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` - Validate Step 4 report
  template, "Authors Shape Warnings" section.
- `agent-system/extensions/literature/scripts/literature-normalize-authors.sh` - header comment
  block, `usage()`, and the argument-parsing `case`.

**Verification**:
- `bash literature-normalize-authors.sh <index> --dry-run` exits 0 and prints the same preview
  output as the bare invocation.
- `bash literature-normalize-authors.sh <index>` (bare) is byte-identical in output to before the
  change.
- `bash literature-normalize-authors.sh <index> --apply` still parses (verify against a
  throwaway copy of the index, never the live one).
- `bash literature-normalize-authors.sh <index> --bogus` still exits 1 with `Unknown argument`.
- `bash -n` passes on the script.

---

### Phase 3: End-to-end validation and deferred-findings record [NOT STARTED]

**Goal**: Confirm the full validate flow is correct against the live corpus, confirm the
source-store boundary was respected, and record the two deferred adjacent findings for the team
lead.

**Tasks**:
- [ ] Run the complete corrected Validate Step 1-4 flow against `~/Projects/Literature/index.json`
      end to end (read-only; no index writes).
- [ ] Confirm `git status --short` shows modifications only under
      `agent-system/extensions/literature/**` and `specs/071_*/**` — zero `.claude/**` paths.
- [ ] Confirm the quarantine-artifact conclusion still holds: `.md.rejected` and `.md.bak-*`
      files remain invisible to both the stale check and the unindexed-file scan.
- [ ] Write the implementation summary recording: the confirmed directory-entry count and
      genuinely-missing count, the before/after stale-entry counts, and the two deferred
      findings (token-drift re-baselining; the `sources/diamondsareforever/chunk_0001.md`
      legacy-`chunks_dir` / current-`path` schema co-mingling with `token_count: 95000` against
      a 903-byte chunk) as explicit follow-up candidates for the team lead to schedule.

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Scope Hypothesis**: The expected outcome is that the stale-entry count drops to zero and the
drift-entry count is unchanged apart from any directory entries that were previously never
recounted. Confirm both numbers by direct observation; if the stale count is non-zero after the
fix, each remaining entry must be individually explained in the summary as a genuine miss rather
than dismissed.

**Files to modify**:
- `specs/071_fix_validate_directory_path_false_positives_and_flag_mismatch/summaries/01_validate-dirpath-flag-fix-summary.md` -
  implementation summary with confirmed counts and deferred findings.

**Verification**:
- Full corrected validate flow completes without error against the live index.
- Zero false-positive stale entries.
- `git status --short` contains no `.claude/**` entry.
- Summary file exists and names both deferred findings with enough detail to act on without
  re-reading the research report.

---

## Testing & Validation

- [ ] Extracted Validate Step 2 block runs clean against `~/Projects/Literature/index.json` with
      zero directory-path entries in `stale_entries`.
- [ ] A fabricated entry pointing at a non-existent directory is still reported stale (the
      existence check was not weakened).
- [ ] File-path entry behavior (drift, schema, authors-shape) is unchanged versus the Phase 1
      pre-change baseline.
- [ ] Directory-path entries are now covered by the schema-field and authors-shape checks.
- [ ] `literature-normalize-authors.sh` accepts `--dry-run`, `--apply`, `--write`, and bare
      invocation; rejects unknown flags with exit 1; `bash -n` clean.
- [ ] No `.claude/**` file modified.

## Artifacts & Outputs

- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` (Validate Step 2 branch
  structure and prose preamble; Validate Step 4 report template sentence)
- `agent-system/extensions/literature/scripts/literature-normalize-authors.sh` (header comment,
  `usage()`, argument-parsing `case`)
- `specs/071_fix_validate_directory_path_false_positives_and_flag_mismatch/summaries/01_validate-dirpath-flag-fix-summary.md`

## Rollback/Contingency

Both changes are confined to two files in the source store with no schema, data, or index
mutation. Revert with `git checkout` of the two paths (or `git revert` of the phase commits);
the deployed `.claude/` copy is regenerated from the source store and needs no separate rollback.
If the Phase 1 restructure proves to regress file-path entry behavior against the baseline,
fall back to the minimal form — add only the directory branch, leave the `jq` checks in the
file-only `else` — which closes the reported defect without the coverage improvement, and record
the coverage gap as a follow-up.
