# Research Report: Task #106

- **Task**: 106 - Route skill literature convert through gated pipeline
- **Started**: 2026-09-01T00:00:00Z
- **Completed**: 2026-09-01T00:30:00Z
- **Effort**: 6-10 hours (per TODO.md estimate)
- **Dependencies**: None (coordination note only: task 89 also restructures this same SKILL.md;
  this task's edit is localized to Mode: Convert and should not block on 89)
- **Sources/Inputs**: Codebase reading only (no web search needed — this is a self-contained
  internal-consistency defect)
  - `agent-system/extensions/literature/skills/skill-literature/SKILL.md` (Mode: Convert, Steps
    1-4; also Mode: Ingest and the Error Handling section)
  - `agent-system/extensions/literature/scripts/literature-convert.sh` (full read)
  - `agent-system/extensions/literature/scripts/literature-ingest.sh` (the sibling caller that
    already delegates correctly — used as the reference implementation pattern)
  - `agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` (existing test
    coverage surface)
  - `specs/TODO.md` (task 106's canonical description, task 105's related OCR-tier task)
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md

## Executive Summary

- Confirmed by direct code reading: `skill-literature`'s Mode: Convert (`handle_convert`, Convert
  Step 3b) extracts text via a bare `pdftotext -layout "$src" -` (PDF) or bare `djvutxt "$src"`
  (DJVU) call and never touches `literature_quality_gate.py` or `literature-convert.sh` at any
  point in its 4-step flow. This is a second, ungated, weakest-tier conversion implementation
  living entirely inside `SKILL.md`'s prose/pseudocode.
- `literature-ingest.sh` (the `/literature --ingest` path, Mode: Ingest) is the correct reference
  implementation already in the codebase: it calls `literature-convert.sh`, captures its exit
  code explicitly (0/2/3), and on exit 3 (gate rejection) logs the rejection reason and skips the
  file — never writing an index entry. This exact pattern is what Mode: Convert needs to adopt.
- **Recommended scope decision: option (i)** — delegate text extraction in Convert Step 3b to
  `literature-convert.sh`, feeding its output into the *unchanged* existing chunk-boundary
  detection, interactive `AskUserQuestion` prompts, and `index.json`/`literature-chunk.sh` writes.
  Delegation does not conflict with the interactive UX: `literature-convert.sh` only produces
  gated whole-document markdown text; it has no opinion on how that text is subsequently split
  into sections or what metadata prompts follow. Nothing in Steps 3c-3h needs to change.
- The tier gap and the gate gap have the same fix: switching the text source to
  `literature-convert.sh` simultaneously restores the `pymupdf4llm` primary tier / PyMuPDF
  fallback tier ordering, and reinstates the quality gate, and removes the duplicate DJVU
  extraction call — one code change resolves all three defects named in the task description.
- A secondary, non-blocking finding: Convert Step 2's hard `pdftotext`-missing gate
  (`SKILL.md:744-748`) becomes incorrect once Step 3b stops needing `pdftotext` in the normal
  (`auto`) path — it would wrongly block conversion on a machine that has PyMuPDF/pymupdf4llm but
  not poppler-utils. Recommend loosening or removing it as part of the same change, since it sits
  in the same code region.

## Context & Scope

Scope is exactly what the task description states: make `/literature <path>` (Mode: Convert) run
every conversion through the same quality-gated, tiered engine that `/literature --ingest`
(Mode: Ingest) already uses via `literature-convert.sh`. No other mode, and no change to the gate
itself (`literature_quality_gate.py`) or the engine tiers (`literature-convert.sh`) is in scope —
those are covered by sibling tasks in this cluster (e.g. task 105's OCR-tier task).

`skill-literature/SKILL.md` is a **direct-execution skill**: its "Steps" are prose/pseudocode
instructions that an agent executes live via the `Bash`/`AskUserQuestion` tools, not a
standalone shell script. The fix is therefore an edit to the instructional text and embedded
bash snippets in `SKILL.md`, not to a separate script file (aside from removing the now-unused
`pdftotext`/`djvutxt` direct-extraction snippets).

## Findings

### The two conversion paths, confirmed

**Path A — `/literature --ingest` (Mode: Ingest), already gated.**
`SKILL.md` Ingest Step 2 (`SKILL.md:115-141`) delegates the entire ingest to
`literature-ingest.sh`, which at `literature-ingest.sh:219-244`:
```
if CONVERT_STDOUT=$("$SCRIPT_DIR/literature-convert.sh" "$source_file" "$TMP_MD_DIR" 2>"$CONVERT_STDERR_FILE"); then
  CONVERT_EXIT=0
else
  CONVERT_EXIT=$?
fi

if [ "$CONVERT_EXIT" -eq 3 ]; then
  GATE_REASON=$(grep -m1 'QUALITY GATE FAILED' "$CONVERT_STDERR_FILE" ...)
  log "QUALITY GATE FAILED: $BASENAME — ${GATE_REASON#*QUALITY GATE FAILED: }"
  GATE_FAILED_ENTRIES+=(...)
  GATE_FAILED=$((GATE_FAILED + 1))
  rm -rf "$TMP_MD_DIR"; rm -f "$CONVERT_STDERR_FILE"
  continue
elif [ "$CONVERT_EXIT" -ne 0 ]; then
  # hard failure, logged, skipped
```
This is the exact reference pattern for exit-code handling and rejection surfacing that
Mode: Convert needs.

**Path B — `/literature <path>` (Mode: Convert), ungated, confirmed unfixed.**
`SKILL.md` Convert Step 3b (`SKILL.md:783-793`):
```bash
if [ "$ext" = "pdf" ]; then
  full_text=$(pdftotext -layout "$src" - 2>/dev/null)
elif [ "$ext" = "djvu" ]; then
  full_text=$(djvutxt "$src" 2>/dev/null)
fi
```
`full_text` then flows directly into Step 3b's heading-detection chunking algorithm, Step 3c's
`AskUserQuestion` chunk-boundary confirmation, Step 3d's chunk-file writes, Step 3e's
auto-metadata generation, Step 3f's bibliographic-metadata prompts, Step 3g's `index.json`
write, and Step 3h's `literature-chunk.sh` call. `literature_quality_gate.py` and
`literature-convert.sh` are never referenced anywhere in Mode: Convert. `pdftotext -layout` is
literature-convert.sh's own last-resort, explicit-override-only tier (never used by its `auto`
mode) — so Mode: Convert both skips the gate and always lands on the weakest available engine,
confirming both halves of the task description's claim.

`goldblatt_1989` (ingested 2026-08-26, 74 chunks, present in both the global index and this
repo's sub-index per the task description) is direct evidence this path is live and has already
produced at least one badly-garbled indexed document with no gate warning.

### Why delegation (option i) is the right shape, not gate-bolt-on (option ii)

The task description frames this as a choice to weigh: delegate to `literature-convert.sh`
entirely (i), or keep the inline `pdftotext` extraction and separately invoke
`literature_quality_gate.py` on its output (ii). Reading Mode: Convert's actual steps resolves
the concern that motivated hedging toward (ii) — "the interactive prompts are handle_convert's
reason for existing":

- `literature-convert.sh`'s contract is narrow and self-contained: `<input> <output_dir>` in,
  a single gated whole-document `.md` (or `.md.rejected`) out, via stdin exit code 0/2/3. It has
  no knowledge of and no opinion on chunk boundaries, metadata prompts, or `index.json` — those
  all live in `SKILL.md`'s Convert Step 3c onward, entirely unchanged by this fix.
- Option (ii) would require vendoring a second call path into `literature_quality_gate.py`
  directly from `SKILL.md`'s pseudocode (bypassing `literature-convert.sh`'s engine-tier
  selection, `.rejected`-sibling convention, and exit-code contract), which is exactly the
  "second conversion implementation" the acceptance criteria says must not remain. Option (i)
  removes a duplicate implementation; option (ii) would deepen it by hand-wiring the gate a
  second time outside `literature-convert.sh`.
- The interactive UX (Steps 3c/3f) operates on `full_text`/`raw_text` as plain data. Swapping the
  *source* of `full_text` from a bare `pdftotext` call to `literature-convert.sh`'s output is a
  one-line substitution at the boundary; every downstream interactive step is untouched.

**Recommendation: option (i).**

### Concrete substitution shape for Convert Step 3b

Mirror `literature-ingest.sh`'s per-file temp-dir + explicit-exit-code pattern
(`literature-ingest.sh:214-226`), scoped per source file inside Convert Step 3's existing loop:

1. Create a per-file scratch dir (`mktemp -d`), call
   `"$SCRIPT_DIR/literature-convert.sh" "$src" "$tmp_convert_dir"` capturing stderr to a temp
   file, and capture the exit code explicitly with the same
   `if VAR=$(...); then EXIT=0; else EXIT=$?; fi` idiom `literature-ingest.sh:224-226` uses (safe
   under this skill's `set -e`/`set -u` conventions — a bare `VAR=$(pipeline)` assignment would
   abort the loop on any single file's failure).
2. **Exit 3 (gate rejected)**: extract the `QUALITY GATE FAILED` line from stderr with the same
   `grep -m1` idiom `literature-ingest.sh:229` uses, surface it to the operator (this is the
   "actionable message" the task requires — the gate's own rejection prose is already
   descriptive), and `continue` to the next target file. Do **not** proceed to Step 3c onward for
   this file — no chunk files, no metadata prompts, no `index.json` entry, no
   `literature-chunk.sh` call. This is the load-bearing behavior the acceptance criteria names:
   "a rejected document must ... never be written to the index as though it converted cleanly."
3. **Exit 2 or 1 (hard failure — all engine tiers failed / bad input)**: same skip-with-message
   pattern, replacing the current "Empty pdftotext output" warning
   (`SKILL.md:2470`/Convert Step 3d's `raw_text` empty-check) with the actual engine failure
   reason from stderr.
4. **Exit 0 (success)**: read the single `.md` file `literature-convert.sh` wrote into
   `tmp_convert_dir` (glob-match `ls "$tmp_convert_dir"/*.md`, mirroring
   `literature-ingest.sh:251-255`'s "derive the doc_id from the actual output filename, don't
   assume" pattern — do not reconstruct the filename from `literature-convert.sh`'s own
   lower-cased/sanitized `$DOC_ID` derivation, which is a different string than Mode: Convert's
   own `basename_no_ext`). Assign its contents to `full_text` and fall through unchanged into
   the existing Step 3b heading-detection algorithm.
5. Apply the same substitution to the DJVU branch: `literature-convert.sh` already has its own
   DJVU path (`djvutxt`, or `djvups | ps2pdf` into the unified PyMuPDF-family engine — see
   `literature-convert.sh`'s `try_djvu()`), so routing both `pdf` and `djvu` extensions through
   one delegated call removes the second `djvutxt` call site entirely, which is what the
   acceptance criterion "no second conversion implementation remains in the skill" requires.
6. Note a beneficial side effect, not a required change: `literature-convert.sh`'s markdown
   output already carries real `#`/`##`/`###` heading markers (from embedded TOC or heuristic
   detection) when produced by the `pymupdf4llm`/PyMuPDF tiers. Step 3b's existing markdown-
   heading regex branch (`^#{1,3}[[:space:]]+\S`) will fire more often and more accurately than
   it did against raw `pdftotext -layout` output — no separate work needed to benefit from this.

### Secondary finding: Convert Step 2's tool gate becomes wrong

Convert Step 2 (`SKILL.md:741-748`) hard-errors out of Mode: Convert entirely if `pdftotext` is
absent:
```bash
if [ "$has_pdftotext" = "no" ]; then
  echo "Error: pdftotext not found. Install with: nix-env -iA nixpkgs.poppler_utils"
  exit 1
fi
```
Once Step 3b delegates to `literature-convert.sh` in its default (`auto`) mode, `pdftotext` is no
longer needed for ordinary conversion — it is only used by `literature-convert.sh` under an
explicit `LITERATURE_CONVERTER=pdftotext` override that Mode: Convert has no reason to set. A
machine with a working `pymupdf4llm`/PyMuPDF stack but no poppler-utils installed would be
incorrectly blocked by this pre-check even though conversion would otherwise succeed.
Recommend loosening this check (e.g. drop it and let `literature-convert.sh`'s own exit 2 "all
engine tiers failed" carry the failure, as `literature-ingest.sh` already does with no equivalent
pre-check) or downgrading it to a non-fatal warning. This sits in the same code region as the
Step 3b fix and is cheap to fold into the same change, but is not required by the stated
acceptance criteria — flagging for the planner to decide whether to include.

The parallel `has_djvutxt` check (used in Step 3a for page-count and as a soft-skip guard) can
stay as-is: `literature-convert.sh`'s DJVU path still needs `djvutxt` (or `djvups`+`ps2pdf`), so
that prerequisite doesn't change.

### Error Handling section staleness

`SKILL.md`'s "Error Handling" section (`SKILL.md:2462-2470`) documents:
```
- pdftotext missing: Hard error for convert mode on PDF files
- djvutxt missing: Soft warning — skip DJVU files
- Empty pdftotext output: Warn "no text extracted, OCR required", skip file, continue
```
These three lines describe the old inline-extraction failure modes and should be updated to
describe the new delegated-conversion failure modes (gate rejection -> skip with rejection
message; engine-tier exhaustion -> skip with reason; `pdftotext` no longer a hard prerequisite)
once Step 3b changes, so the documented error contract matches the actual behavior.

### Test coverage gap

`agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` exercises
`literature-convert.sh` directly (forced-fallback tier, column-interleaving fixtures) but nothing
currently exercises Mode: Convert's delegation to it, since that delegation doesn't exist yet.
The acceptance criteria's verification step ("an ingest of a known-bad document through
`/literature <path>` produces a visible gate rejection") is inherently a live/manual
`/literature <path>` run rather than something `test-literature-convert.sh`'s scripted-fixture
harness covers — the implementer should treat that manual run as the acceptance check, and
should decide separately whether a light-weight automated check of the delegation call site
(e.g. mocking `literature-convert.sh`'s exit code) is worth adding to the test suite.

## Decisions

- **Scope decision resolved: option (i), delegate.** Replace Convert Step 3b's inline
  `pdftotext -layout`/`djvutxt` extraction with a call to `literature-convert.sh`, feeding its
  gated markdown output into the unmodified existing chunking/prompting/indexing steps.
- The DJVU direct-extraction call is folded into the same delegation (both extensions route
  through `literature-convert.sh`), fully satisfying "no second conversion implementation
  remains in the skill."
- Convert Step 2's `pdftotext`-availability hard gate is a related but separable fix; recommend
  including it in the same task since it is adjacent and cheap, but it is not required by the
  stated acceptance criteria.

## Recommendations

1. Rewrite Convert Step 3b in `SKILL.md` to delegate to `literature-convert.sh` per the
   substitution shape above, using `literature-ingest.sh`'s exit-code-handling block
   (`literature-ingest.sh:219-244`) as the direct model to copy the pattern from (not just the
   general idea — the `grep -m1 'QUALITY GATE FAILED'` extraction and the explicit
   `if VAR=$(...); then/else` exit-capture idiom should be reused verbatim).
2. On gate rejection (exit 3) or hard failure (exit 1/2), skip straight to the next target file
   in Convert Step 3's loop — do not enter Steps 3c-3h for that file.
3. Update the "Empty pdftotext output" and "pdftotext missing" lines in the Error Handling
   section (`SKILL.md:2462-2470`) to reflect the new delegated failure modes.
4. Loosen or remove Convert Step 2's hard `pdftotext`-missing gate (secondary fix, same region,
   recommended but not required).
5. Verify via a live `/literature <path>` run against a known-bad (garbled/scanned) PDF that the
   rejection is now visible and no `index.json` entry or chunk files are written for it — this is
   the acceptance criterion's own verification method, not a scripted test.
6. No change needed to `literature-convert.sh`, `literature_quality_gate.py`, or
   `literature-chunk.sh` — this task is purely about wiring Mode: Convert to the pipeline that
   already exists.

## Risks & Mitigations

- **Risk**: `basename_no_ext` (Mode: Convert's own naming, preserves original case, used for
  `chunk_dir`/`output_files`) could be conflated with `literature-convert.sh`'s internal
  lower-cased/sanitized `$DOC_ID` (used only for its own `OUTPUT_MD` filename inside the tmp
  dir), silently changing existing chunk/output file naming conventions.
  **Mitigation**: glob-match the tmp dir's single `.md` file for content only (as
  `literature-ingest.sh:251-255` does), and keep deriving all downstream file/dir names from
  Mode: Convert's existing `basename_no_ext`, unchanged.
- **Risk**: Removing the `pdftotext` hard gate (secondary fix) without verifying
  `literature-convert.sh`'s own failure path is loud enough could regress the operator experience
  if all engine tiers are genuinely unavailable.
  **Mitigation**: `literature-convert.sh` exit 2 ("all engine tiers failed") is already
  loud-failure by design (see its own header contract) — no additional work needed, just don't
  reintroduce a redundant pre-check that fails on the wrong condition.
- **Risk**: Coordination with task 89, which restructures this same `SKILL.md` wholesale into
  mode-gated sections. TODO.md's own coordination note on task 89 already addresses this
  directly: land this task first (small, localized) and let 89 carry the corrected text through
  its restructure; if 89 lands first, re-locate Convert Step 3b in the new structure rather than
  assuming current line numbers.

## Appendix

- `agent-system/extensions/literature/scripts/literature-convert.sh` — full interface contract:
  usage, engine tiers, environment variables (`LITERATURE_CONVERTER`, `LITERATURE_PYENV_DIR`),
  and exit codes 0/1/2/3, documented in its own header comment (lines 1-63).
- `agent-system/extensions/literature/scripts/literature-ingest.sh:177-273` — the reference
  delegation-and-exit-code-handling implementation this task should mirror.
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md:719-1220` — full current
  text of Mode: Convert (Steps 1-4) that Step 3b's substitution lands inside.
- Related sibling tasks (not in scope here): task 105 (OCR tier for image-only/poor-vintage
  scans), task 89 (SKILL.md mode-gated restructure — coordination note only, no dependency).
