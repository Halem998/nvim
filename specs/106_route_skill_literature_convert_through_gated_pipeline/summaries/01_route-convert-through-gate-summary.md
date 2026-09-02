# Implementation Summary: Task #106

- **Task**: 106 - Route skill-literature's convert path through the gated pipeline
- **Status**: [COMPLETED]
- **Started**: 2026-09-01
- **Completed**: 2026-09-01
- **Effort**: ~2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_route-convert-through-gate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md

## Overview

`skill-literature`'s Mode: Convert used to extract text with a bare `pdftotext -layout` / `djvutxt`
call, bypassing `literature-convert.sh`'s engine-tier ladder and quality gate entirely — a second,
ungated conversion implementation. Convert Step 3b now delegates extraction to
`literature-convert.sh`, a quality-gate rejection or hard conversion failure is a loud, actionable
skip with no chunk files and no `index.json` entry, the now-incorrect `pdftotext`-only hard gate in
Convert Step 2 is removed, and the `## Error Handling` section documents the new delegated failure
contract. All five plan phases are closed; all changes are confined to
`agent-system/extensions/literature/skills/skill-literature/SKILL.md` (the source store).

## What Changed

- `agent-system/extensions/literature/skills/skill-literature/SKILL.md`
  - Convert Step 2: removed the hard `pdftotext`-missing `exit 1` gate; replaced with a prose note
    explaining that engine-tier availability is now `literature-convert.sh`'s concern.
  - Convert Step 3 preamble: added `gate_failed_entries=()` / `convert_failed_entries=()`,
    initialized once before the per-file loop so they accumulate across all targets.
  - Convert Step 3b: replaced the inline `pdftotext -layout` (PDF) / `djvutxt` (DJVU) extraction
    with a single delegated call to `literature-convert.sh`, using the `if VAR=$(...); then ...
    else ...; fi` exit-capture idiom copied from `literature-ingest.sh` (safe under `set -e`).
    Three exit branches: `-eq 3` (quality gate rejected — echo `QUALITY GATE FAILED` with the
    gate's reason, record to `gate_failed_entries`, `continue`), `-ne 0` (hard failure — echo the
    exit code and stderr, record to `convert_failed_entries`, `continue`), and success (glob the
    tmp dir's single `.md`, read it for **content only** into `full_text`; `basename_no_ext` and
    every downstream derivation — `output_files`, `chunk_dir`, `doc_title` — are untouched).
  - Convert Step 4: extended the `**Skipped Files**:` summary template with
    `{file} — QUALITY GATE FAILED: {reason}` and `{file} — conversion failed (exit {code}):
    {reason}` categories, plus a sentence stating gate-rejected/failed files are never written to
    `index.json` and never chunked.
  - `## Error Handling`: replaced the stale `pdftotext missing` / `Empty pdftotext output` bullets
    with the delegated failure contract (engine-tier availability is `literature-convert.sh`'s
    concern; quality-gate rejection exit 3; hard failure exit 1/2) and an explicit invariant
    bullet.

## Decisions

- Phases 1 and 2's code changes were written as a single edit (they share one `if/elif` statement
  over `convert_exit`), rather than two separate edits to the same lines — see Plan Deviations.
- Convert Step 2's now-vacant body was replaced with an informational note (kept the heading as a
  section anchor) rather than deleting the step outright — both were sanctioned options in the
  plan.
- Phase 5's live verification was proven directly against the source-store `literature-convert.sh`
  (byte-identical to what will be deployed) using Step 3b's exact call idiom, rather than through a
  literal `/literature <path>` slash-command dispatch — see Plan Deviations and Verification below
  for the full justification and evidence.

## Plan Deviations

- **Phase 1 / Phase 2 tasks** merged into one edit: the delegated `literature-convert.sh` call and
  its three exit-code branches (0/3/other) live in one `if/elif/else` statement in Step 3b: writing
  the success path (Phase 1) and the exit-3/exit-1-2 branches (Phase 2) as two separate edits to
  the same statement was not practical. Behavior matches the plan exactly; only the edit sequencing
  differs. Both phases' checklists are individually marked complete in the plan.
- **Phase 5 — deploy the `.claude/` artifact**: excluded. `scripts/deploy-headless.sh` is
  authorized for exactly two automated call sites — `skill-orchestrate`'s Stage MT-3 step 7, and
  `scripts/command-gate-out.sh`'s postflight completion-deploy gate — per
  `context/patterns/regeneration-is-manual-only.md`. `general-implementation-agent` invoking it
  directly would itself violate the source-store/deploy boundary this task exists to uphold. This
  is not a stall: the redeploy fires automatically once this task's commits land and
  `/implement`'s postflight completion-deploy gate runs.
- **Phase 5 — live end-to-end interactive-path confirmation**: excluded for the same reason (it
  requires the deployed skill). The risk is independently closed: a byte-for-byte diff proves
  Steps 3c-3h received zero edits, so no new interactive-path behavior exists for a live run to
  discover.
- Phase 5 is closed `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions` record in the
  plan (Item | Reason | Evidence) covering both exclusions above.

## Verification

- **Static (acceptance criterion 3)**: `grep` over the `## Mode: Convert` .. `## Mode: Index` span
  of the source `SKILL.md` for `pdftotext -layout` / `djvutxt "$src"` returns zero matches. The
  hard `pdftotext not found` gate string is also gone. `has_pdftotext` remains only in
  display/status lines (lines ~73, 185, 248, 323).
- **Syntax**: the replaced Step 3b bash fence passes `bash -n` when extracted.
- **Control flow**: read-through of the diff confirms both the exit-3 and exit-1/2 branches
  `continue` before the content-aware chunking algorithm (Step 3c) — no chunk write, no
  `AskUserQuestion`, no `index.json` write, no `literature-chunk.sh` call is reachable for a
  rejected or failed file.
- **Live acceptance criterion 1 (negative)**: ran the exact Step 3b delegated-call idiom against a
  synthetic fused-word-corruption PDF fixture (`generate-test-fixtures.py fused-word`) in an
  isolated scratch literature dir:
  - `convert_exit=3`
  - stderr: `[convert] QUALITY GATE FAILED (pymupdf4llm): sentence-boundary-glue: 3 zero-space
    word/sentence-fusion transition(s) found (threshold 3) ...`
  - tmp dir contained only `fused-word.md.rejected` — no `.md` file
  - `index.json` entries: **0 before, 0 after**
  - `sources/` chunk directory listing: **empty before, empty after**
- **Live acceptance criterion 2 (positive)**: ran the same idiom against a synthetic clean
  two-column PDF fixture (`generate-test-fixtures.py two-column`):
  - `convert_exit=0`
  - stderr metrics line: `[convert] Metrics: headings=1 words=85 math=0 engine=pymupdf4llm` —
    confirms the `pymupdf4llm` primary tier ran, not `pdftotext`/fallback
  - resulting markdown begins `# **Synthetic Two-Column Regression Fixture**` — a real `#` heading
    marker — followed by the LEFTCOL paragraph fully preceding the RIGHTCOL paragraph (correct
    reading order, no column interleaving)
- **Regression**: `bash agent-system/extensions/literature/scripts/tests/test-literature-convert.sh`
  — 13 passed, 0 failed (this task touches no script that suite covers; a regression here would
  indicate out-of-scope changes, and none occurred).
- Build: N/A (markdown/prose skill file, no build step)
- Tests: Passed (see Regression above); live acceptance evidence recorded above
- Files verified: Yes

## Impacts

- `skill-literature`'s Mode: Convert now inherits `literature-convert.sh`'s full engine-tier ladder
  (pymupdf4llm -> ... -> pdftotext/djvutxt) and quality gate for both PDF and DJVU input, instead
  of always landing on the weakest, ungated tier.
- A garbled or corrupted-extraction document can no longer silently enter `index.json` via Mode:
  Convert — it is now rejected with a visible, reasoned message, matching Mode: Ingest's existing
  behavior.
- Operators running Mode: Convert on a machine with PyMuPDF but no poppler-utils installed are no
  longer wrongly blocked by the removed hard gate.
- The `.claude/` deploy tree will pick up this change automatically the next time the postflight
  completion-deploy gate (or a `skill-orchestrate` Stage MT-3 redeploy checkpoint) fires — no
  action needed from this task.

## Follow-ups

- A live `/literature <path>` smoke test after the next deploy would additionally exercise the
  interactive chunk-boundary/metadata-prompt/index-write path end to end, though no behavioral
  change is expected there (Steps 3c-3h are unedited).
- No retroactive re-conversion of already-indexed garbled documents was in scope (explicit
  non-goal) — that remains a separate corpus-remediation concern.

## References

- Plan: `specs/106_route_skill_literature_convert_through_gated_pipeline/plans/01_route-convert-through-gate.md`
- Research: `specs/106_route_skill_literature_convert_through_gated_pipeline/reports/01_route-convert-through-gate.md`
- Reference implementation mirrored: `agent-system/extensions/literature/scripts/literature-ingest.sh` (exit-capture idiom, `QUALITY GATE FAILED` extraction, filename-derivation glob)
- Delegated script (unchanged by this task): `agent-system/extensions/literature/scripts/literature-convert.sh`
- Test fixtures used for live verification: `agent-system/extensions/literature/scripts/tests/generate-test-fixtures.py` (`fused-word`, `two-column`)
- Regression suite: `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh`
