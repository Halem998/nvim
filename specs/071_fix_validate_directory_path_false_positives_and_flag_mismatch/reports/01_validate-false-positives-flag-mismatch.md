# Research Report: Task #71

**Task**: 71 - Fix validate directory-path false positives and flag mismatch
**Started**: 2026-08-18
**Completed**: 2026-08-18
**Effort**: small (2 low-severity doc/logic fixes)
**Dependencies**: None (sequenced after task 69's quality-gate hardening, read for context)
**Sources/Inputs**: Codebase (SKILL.md, literature-normalize-authors.sh), live global index at
  `~/Projects/Literature/index.json` (369 entries), task 69 summary
**Artifacts**: this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **Defect 1 confirmed and reproduced**: `agent-system/extensions/literature/skills/skill-literature/SKILL.md:381`
  (`Validate Step 2`) tests every indexed entry with `[ ! -f "$full_path" ]`. This fails for every
  directory-path entry (paths ending in `/`, used by book/parent-level entries), because `-f` is
  false for directories even when they exist. Reproduced directly: all 34 directory-path entries
  in the live global index exist as real directories (`sources/blackburn_2002/`,
  `sources/caleiro_2013/`, `sources/gabbay_1993/`, etc. all verified with `-d`/`-f`), so every one
  of them would be wrongly reported stale. The teammate's earlier live run counted 65 (the
  larger, since-modified corpus at the time of that run) — the mechanism is the same bug in both
  counts. Fix: branch on `-d "$full_path"` (path ends in `/` or is a directory) vs `-f`, and skip
  or adapt the token-drift recount for directory entries (they have no single readable content
  file; `token_count` for these entries is a whole-book aggregate, not a per-file count — see
  Findings below).
- **Defect 2 confirmed and reproduced**: `SKILL.md:486` tells the user to run
  `literature-normalize-authors.sh {index_file} --apply` "or `--dry-run` (default) first to
  preview the change." `literature-normalize-authors.sh` has no `--dry-run` flag — its `usage()`
  (line 33-38) and arg-parsing `case` (lines 55-60) accept only `--apply`/`--write`; passing
  `--dry-run` hits the `*) echo "Unknown argument: $arg" >&2; usage` branch and exits 1. Dry-run
  is correctly the bare-no-flag default (confirmed in the script's own header comment, lines
  13-15), but the flag literally named in the doc does not exist. Fix: correct the doc text to
  say "or run with no flag (default) to preview the change first" — do not add a `--dry-run`
  alias to the script, since that would only paper over doc wording that is already wrong about
  the mechanism (bare-invocation-is-default, not flag-gated).
- Both defects are documentation/logic-only; no data corruption risk, no schema change needed.
  Recommended scope: fix the `-f`/`-d` branch in SKILL.md's Validate Step 2 pseudocode, and fix
  the one sentence in SKILL.md's Validate Step 4 report template. `literature-normalize-authors.sh`
  itself needs no code change for Defect 2.

## Context & Scope

Task 71 was scoped by the team lead from a real `/literature --validate` run against the live
`~/Projects/Literature/index.json` (369 entries, later observed at 368/369 across two checks in
this session — the corpus is being actively modified by concurrent task 069/070 work). Two
defects were reported plus three adjacent, non-blocking findings (token-drift baseline drift, four
genuinely-real drift entries, and an informational non-defect on `authors`-shape normalization).
This report independently reproduces the two in-scope defects against the current source tree and
verifies the adjacent findings still hold, factoring in task 069's just-completed quality-gate
hardening (`specs/069_harden_conversion_quality_gate_against_mojibake/`) per the team lead's
sequencing note.

## Findings

### Codebase Patterns

**Defect 1 — directory-path stale false positive** (`agent-system/extensions/literature/skills/skill-literature/SKILL.md:377-397`):

```bash
stale_entries=()
...
while IFS= read -r entry_path; do
  full_path="$lit_dir/$entry_path"
  if [ ! -f "$full_path" ]; then
    stale_entries+=("$entry_path (missing)")
  else
    # Recount tokens
    char_count=$(wc -c < "$full_path" 2>/dev/null || echo 0)
    ...
```

`entry_path` for a book/parent-level entry is a directory path such as `sources/blackburn_2002/`
(trailing slash). `[ ! -f "$full_path" ]` is true for a directory regardless of whether it
exists, so every directory-path entry is unconditionally pushed into `stale_entries`, and the
`else` branch (token recount) never runs for these entries either — meaning today's validate
report both wrongly flags them as missing AND silently skips their token-drift check, which masks
a real signal (see "Adjacent — genuinely real drift" below for the four entries this would have
caught).

Directory-path entries carry `"doc_type": "book"` and represent the parent index record for a
book split into many semantic chunks (verified live example, `sources/blackburn_2002/`, `id:
"blackburn_2002_book"`, `path: "sources/blackburn_2002/"`, `token_count: 0`). Their `path` is
deliberately a directory, not a file — this is a legitimate second schema variant alongside the
single-file `path` variant used by paper-level and chunk-level entries, not a malformed record.
34 such entries exist in the live global index; all 34 verified to exist as real directories via
direct `-d`/`-f` checks in this session.

Minimal fix shape:
```bash
if [[ "$entry_path" == */ ]] || [ -d "$full_path" ]; then
  [ -d "$full_path" ] || stale_entries+=("$entry_path (missing directory)")
  # directory entries: no single content file to recount tokens against; skip drift check
  # or (better) sum token_count-equivalent across the directory's chunk files if a
  # meaningful aggregate check is wanted — out of scope for this minimal fix.
elif [ ! -f "$full_path" ]; then
  stale_entries+=("$entry_path (missing)")
else
  # existing single-file recount logic unchanged
  ...
fi
```
The `authors`-shape and required-schema-field checks below the `else` branch in the same loop
iteration are unaffected by this change since they read from `index.json` via `jq`, not the
filesystem.

**Defect 2 — flag mismatch** (`agent-system/extensions/literature/skills/skill-literature/SKILL.md:485-487`
vs. `agent-system/extensions/literature/scripts/literature-normalize-authors.sh:33-60`):

SKILL.md's Validate Step 4 report template, under "Authors Shape Warnings", instructs:
```
Run: bash .claude/scripts/literature-normalize-authors.sh {index_file} --apply to normalize,
or --dry-run (default) first to preview the change.
```
The script's actual usage contract:
```
Usage: literature-normalize-authors.sh <index.json> [--apply|--write]
...
By default this script runs in DRY-RUN mode: ...
Pass --apply (or --write) to persist changes in place.
```
and its arg-parsing loop's only branches are `--apply|--write` (sets `apply=true`) and a catch-all
`*) echo "Unknown argument: $arg" >&2; usage` that exits 1 for any other token, including
`--dry-run`. Reproducing: `literature-normalize-authors.sh <index> --dry-run` prints `Unknown
argument: --dry-run` and the usage block, then exits 1 — it does not silently no-op, it hard-fails.
The doc's parenthetical "(default)" is correct in substance (no flag = preview-only) but the
sentence's imperative phrasing ("or `--dry-run` ... first") reads as "you may also pass
`--dry-run` explicitly," which is false.

Fix is doc-only: reword to something like `or run with no flag (dry-run is the default) to
preview the change first`. No `--dry-run` no-op alias should be added to the script — the script
comment block and `usage()` already correctly describe bare-invocation-as-default; adding a
flag alias would just create two ways to say the same thing for no functional gain, and drifts
from the script's own header documentation which was presumably the doc author's actual intent
(they meant "the default", not "a flag named `--dry-run`").

### Adjacent Findings (verified, informational — not in fix scope unless the team lead wants them folded in)

- **Token-drift baseline** (Adjacent Finding A): confirmed non-blocking. Spot-checked 8
  `blackburn_2002` chapter files directly — every one comes back within ratio 1.001-1.003
  (stored vs. recomputed `char_count/4+20`), i.e. essentially in sync, not drifted. This means the
  systematic drift the teammate found (55/56 same-direction, 40+ in a 1.21-1.35 band) is
  concentrated in a different subset of the corpus than the sample checked here, consistent with
  their framing that it is a "changed token formula or bulk re-conversion" for a specific batch,
  not a corpus-wide drift. `token_count` is written by `literature-build-index.sh` /
  `literature-chunk.sh` (and the Zotero-side `zotero-chunk.sh`), not by `literature-convert.sh`
  itself — task 069's quality-gate hardening touched only `literature-convert.sh` and
  `literature_quality_gate.py`, and per that task's own `git diff` verification changed nothing
  inside the extraction/markdown-derivation functions, so it did not itself alter how
  `token_count` values get written or stored. Re-baselining `token_count` (if pursued) is
  therefore independent of task 069 and can be scheduled separately; it does not need to block on
  or coordinate with anything task 069 changed.
- **Four genuinely-real drift entries** (Adjacent Finding B): confirmed via direct inspection.
  `sources/diamondsareforever/chunk_0001.md`'s index entry mixes the legacy `chunks_dir` schema
  (`"chunks_dir": "/home/benjamin/Projects/Literature/sources/diamondsareforever"`, `"chunk_count":
  56`, absolute path) with the current `path` schema (`"path":
  "sources/diamondsareforever/chunk_0001.md"`) in the same record, `"token_count": 95000` (clearly
  the old whole-document aggregate, not this one 903-byte chunk's count), and
  `"provenance_fidelity": "unverified_no_baseline"`. This is a distinct, more serious schema-shape
  defect (legacy-field/current-field co-mingling) than the two in-scope defects and deserves its
  own follow-up task rather than folding into this one — it is a data-correction problem (which
  `token_count`/`path` pairing is authoritative for this record), not a validate-logic bug. This
  report defers to the team lead's framing: flag for separate follow-up, not fixed here.
- **`authors`-shape check** (informational, confirmed not regressed): the malformed-array pattern
  the check guards against (array elements that are themselves comma-joined strings) has zero
  occurrences in the live index; `literature-normalize-authors.sh` correctly finds only the
  60 string-valued (not array) `authors` fields, which is the tool's designed everyday case, not a
  regression.
- **Quarantine-artifact interaction with task 069** (per team lead's sequencing note): checked
  directly — `.md.rejected` / `.md.bak-*` quarantine artifacts are excluded from validate's stale
  and unindexed-file checks by construction, not by any special-case logic that could interact
  with task 069's changes. Validate Step 2 only iterates `index.json`'s own `.entries[].path`
  values (quarantine artifacts are never indexed), and Validate Step 3's unindexed-file scan uses
  `find "$lit_dir" -maxdepth 1 -name "*.md"`, which does not match `*.md.rejected` or
  `*.md.bak-<suffix>` filenames (they don't end in literal `.md`). One live `.rejected` sibling
  exists in the corpus today
  (`sources/gabbay_2000/gabbay_reynolds_2000_temporal_logic_foundations_vol2.md.rejected`),
  confirming the artifact shape task 069 produces, and it is correctly invisible to both checks.
  Conclusion: task 069's hardening does not change validate's behavior and does not need
  additional handling as part of this task's fix.

## Recommendations

1. Fix `SKILL.md` Validate Step 2 (~line 381): branch on `-d`/trailing-slash for directory-path
   entries before falling through to the existing `-f` file-recount branch, per the pattern shown
   above. Directory entries should be checked for existence (not for staleness via a token
   recount they cannot support) — a directory-path entry with `token_count: 0` and no
   content-file token drift check is expected, not a gap to fill in this task.
2. Fix `SKILL.md` Validate Step 4 (~line 486): reword the `--dry-run` sentence to stop naming a
   nonexistent flag; state that omitting the flag (the default) previews the change.
3. Do not modify `literature-normalize-authors.sh` — its behavior is already correct; only the
   doc pointing at it is wrong.
4. Leave the three adjacent findings (token-drift re-baselining, the `diamondsareforever`
   schema-mixing record, and the `authors`-shape informational note) out of this task's fix scope;
   they were explicitly flagged by the team lead as separate/follow-up concerns, and Findings B in
   particular touches a live data-correctness question (which field is authoritative) that a
   validate-logic fix should not silently paper over by, e.g., special-casing `chunks_dir` in the
   stale check.

## Risks & Mitigations

- **Risk**: the directory-existence fix could mask a genuinely-deleted book directory if the
  `-d` branch only checks existence loosely. **Mitigation**: keep the existence check itself
  (`[ -d "$full_path" ]` must still fail -> stale) — only remove the incorrect `-f` test, don't
  remove the missing-entry detection.
- **Risk**: rewording the doc sentence without touching the script risks the same confusion
  resurfacing if a future contributor adds a `--dry-run` flag to the script without updating the
  doc back. **Mitigation**: none needed beyond normal review; noted for completeness.

## Context Extension Recommendations

None — this is a narrowly-scoped doc/logic fix; no new context file is warranted.

## Appendix

- Search queries / commands used: `grep -n "validate\|dry-run"` over SKILL.md and
  `literature-normalize-authors.sh`; live `-d`/`-f` checks against
  `~/Projects/Literature/index.json`'s 34 directory-path entries; direct token-count ratio
  spot-check against 8 `blackburn_2002` chapter files; `find` for `.rejected`/`.bak-*` artifacts.
- Key files referenced:
  - `agent-system/extensions/literature/skills/skill-literature/SKILL.md` (lines 347-497:
    Validate Step 1-4)
  - `agent-system/extensions/literature/scripts/literature-normalize-authors.sh` (lines 1-60)
  - `specs/069_harden_conversion_quality_gate_against_mojibake/summaries/01_harden-quality-gate-mojibake-summary.md`
  - Live index: `~/Projects/Literature/index.json`
