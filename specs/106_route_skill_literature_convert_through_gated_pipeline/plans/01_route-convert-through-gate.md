# Implementation Plan: Task #106

- **Task**: 106 - Route skill-literature's convert path through the gated pipeline
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: specs/106_route_skill_literature_convert_through_gated_pipeline/reports/01_route-convert-through-gate.md
- **Artifacts**: plans/01_route-convert-through-gate.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`skill-literature`'s Mode: Convert (the `/literature <path>` interactive path) extracts text with a
bare `pdftotext -layout` (PDF) or `djvutxt` (DJVU) call and feeds the result straight into
chunking, metadata prompts, and `index.json` — never touching `literature-convert.sh` or
`literature_quality_gate.py`. This is a second, ungated conversion implementation that also always
lands on `literature-convert.sh`'s weakest, explicit-override-only tier. The fix is to replace the
inline extraction with a delegated `literature-convert.sh` call whose gated markdown output feeds
the *unchanged* downstream Steps 3c-3h, mirroring `literature-ingest.sh`'s already-correct
exit-code-handling block. Definition of done: no direct `pdftotext`/`djvutxt` extraction call
remains in Mode: Convert, a gate rejection produces a visible operator message and no index entry,
and the pymupdf4llm primary tier is reached on a document where it is the right engine.

### Research Integration

The research report resolved the scope decision the task description posed and this plan
implements that decision rather than re-opening it:

- **Option (i), DELEGATE, is chosen.** `literature-convert.sh`'s contract (`<input> <output_dir>`
  in; one gated `.md` or `.md.rejected` sibling out; exit 0/1/2/3) has zero knowledge of chunk
  boundaries, metadata prompts, or `index.json`. All of those live in Convert Steps 3c-3h and stay
  untouched. Only the *source* of `full_text` in Step 3b changes.
- Option (ii) was rejected because hand-wiring `literature_quality_gate.py` from `SKILL.md`
  pseudocode would bypass the engine-tier ladder and the `.rejected`-sibling convention — i.e. it
  would deepen the duplicate implementation the acceptance criteria says must not remain.
- **Reference implementation to mirror verbatim**: `literature-ingest.sh` lines 214-260 — the
  `if VAR=$(...); then EXIT=0; else EXIT=$?; fi` exit-capture idiom (safe under `set -e`), the
  `grep -m1 'QUALITY GATE FAILED'` stderr extraction, and the "derive the doc_id from the actual
  output filename, don't reconstruct it" glob.
- **Naming hazard flagged by research**: `literature-convert.sh`'s internal lower-cased/sanitized
  `$DOC_ID` is a *different string* from Mode: Convert's `basename_no_ext`. The tmp `.md` is read
  for **content only**; every downstream file/dir name keeps deriving from the existing
  `basename_no_ext`.
- The secondary Convert Step 2 `pdftotext`-hard-gate fix is **included** (Phase 3), per the
  planner's discretion the research left open: it sits in the same code region, is cheap, and
  becomes actively incorrect the moment Phase 1 lands.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context; no roadmap consultation performed.

## Goals & Non-Goals

**Goals**:
- Route both PDF and DJVU conversion in Mode: Convert through `literature-convert.sh`, inheriting
  its engine-tier ladder and quality gate.
- Make a quality-gate rejection (exit 3) a loud, actionable operator message that skips the file
  entirely — no chunk files, no metadata prompts, no `index.json` entry, no `literature-chunk.sh`
  call.
- Remove both direct-extraction call sites so no second conversion implementation remains in the
  skill.
- Keep the documented error contract (Error Handling section) in sync with the new behavior.

**Non-Goals**:
- No change to `literature-convert.sh`, `literature_quality_gate.py`, `literature-chunk.sh`, or
  `literature-build-index.sh` (sibling tasks own those).
- No change to Convert Steps 3c-3h: chunk-boundary detection, `AskUserQuestion` prompts,
  chunk-file writes, auto-metadata, bibliographic prompts, `index.json` write, chunk/index rebuild
  all stay exactly as they are.
- No change to Mode: Ingest, Mode: Index, Mode: Validate, Mode: Rebuild, or the Zotero import path.
- No retroactive re-conversion or purge of already-indexed garbled documents (e.g. the
  `goldblatt_1989` entry named in the task description) — that is a corpus-remediation concern, not
  this wiring fix.
- No new OCR tier (owned by the sibling OCR task).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `literature-convert.sh`'s sanitized `$DOC_ID` is conflated with Mode: Convert's `basename_no_ext`, silently changing chunk/output file naming | H | M | Glob the tmp dir's single `.md` for **content only** (mirror `literature-ingest.sh`'s filename-derivation glob); assert in the diff that no downstream `output_files`/`chunk_dir` derivation was touched |
| A bare `full_text=$(literature-convert.sh ...)` assignment aborts the whole target loop on one file's non-zero exit under `set -e` | H | M | Use the `if VAR=$(...); then EXIT=0; else EXIT=$?; fi` idiom verbatim from `literature-ingest.sh`; never a bare command-substitution assignment |
| A gate rejection degrades into a silent skip (the explicit hard constraint) | H | L | Phase 2 is a dedicated phase for rejection surfacing; Phase 5's live acceptance run against a known-bad document is the gate on task completion, not an optional extra |
| Removing Convert Step 2's `pdftotext` pre-check regresses the operator experience when *all* engine tiers are genuinely absent | M | L | `literature-convert.sh` exit 2 ("all converters failed") is loud by design; Phase 2's exit-1/2 handler surfaces its stderr, so the failure is still reported — just at the right condition |
| The sibling SKILL.md mode-gated restructure task lands first and moves Convert Step 3b | M | L | Anchor every edit on section headings (`#### 3b: Extract Full Text...`, `### Convert Step 2: ...`) and grep for the code, never on the line numbers cited in this plan |
| `.claude/` deploy artifact is edited instead of the source store, so the fix is wiped on next regeneration | H | L | Every phase's file target is `agent-system/extensions/literature/**`; Phase 5 treats the `.claude/` copy as regenerated output, never a hand-edit target |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Delegate Convert Step 3b text extraction to literature-convert.sh [COMPLETED]

**Goal**: Replace the inline `pdftotext -layout` / `djvutxt` extraction in Convert Step 3b with a
per-file delegated call to `literature-convert.sh`, so `full_text` arrives already tier-selected
and gate-passed. Downstream chunking logic is untouched.

**Tasks**:
- [x] Locate `#### 3b: Extract Full Text and Determine Chunking` in
      `agent-system/extensions/literature/skills/skill-literature/SKILL.md` by heading (currently
      near line 780) and confirm the two-branch `if [ "$ext" = "pdf" ] ... elif [ "$ext" = "djvu" ]`
      extraction block is still the only text source feeding `full_text`.
- [x] Resolve `SCRIPT_DIR` defensively in the Step 3b snippet using the convention already used
      twice in this file (`SCRIPT_DIR="${SCRIPT_DIR:-$(dirname "$0")/../../scripts}"`, as at the
      doc-key block near line 522) — do not assume Ingest Step 2's assignment is in scope.
- [x] Replace the extraction block with: `tmp_convert_dir=$(mktemp -d)`,
      `convert_stderr=$(mktemp)`, then the delegated call using the exit-capture idiom copied from
      `literature-ingest.sh`:
      `if convert_stdout=$("$SCRIPT_DIR/literature-convert.sh" "$src" "$tmp_convert_dir" 2>"$convert_stderr"); then convert_exit=0; else convert_exit=$?; fi`
- [x] Route **both** `pdf` and `djvu` through the single delegated call — remove the `djvutxt`
      branch entirely (`literature-convert.sh` has its own DJVU path). This is the second of the
      two call sites the acceptance criteria requires gone.
- [x] On `convert_exit -eq 0`: glob the tmp dir for its single `.md`
      (`md_file=$(ls "$tmp_convert_dir"/*.md 2>/dev/null | head -1)`), guard the
      reported-success-but-no-output case the way `literature-ingest.sh` does, and assign
      `full_text=$(cat "$md_file")`. Clean up `tmp_convert_dir` and `convert_stderr`.
- [x] Verify by reading the diff that `basename_no_ext` and every downstream derivation from it
      (`output_files`, `chunk_dir`, `doc_title`) is byte-for-byte unchanged — the tmp `.md` is read
      for content only, never for its name.
- [x] Confirm `total_lines`, `LINE_THRESHOLD`, `MERGE_MIN`, and the entire content-aware chunking
      algorithm below the replaced block are unmodified.
- [x] Add a short comment above the delegated call naming why the `if VAR=$(...)` form is used
      (set -e safety) and why the tmp `.md` is read for content only (doc_id vs. `basename_no_ext`),
      mirroring the explanatory comments `literature-ingest.sh` already carries. *(completed: comment added; the exit-3/exit-1/2 branches from Phase 2 were written in the same edit since they share the same `if/elif` block — see Phase 2's deviation note)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts (a) exactly one extraction block, at
`SKILL.md` ~783-793, is the sole source of `full_text` in Mode: Convert, and (b) exactly two direct
extraction call sites exist in Mode: Convert (`pdftotext` at ~785, `djvutxt` at ~787). Confirm at
implementation time by `grep -n 'pdftotext\|djvutxt' SKILL.md` restricted to the Mode: Convert
section (heading `## Mode: Convert` through `## Mode: Index`) and by reading the block in context;
if the counts or locations differ, re-locate by heading and report the delta before editing.

**Files to modify**:
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` — Convert Step 3b
  extraction block replaced with a delegated `literature-convert.sh` call

**Verification**:
- Extract the Step 3b bash fence to a scratch file and run `bash -n` on it — no syntax errors.
- `grep -n 'pdftotext -layout\|djvutxt "\$src"' SKILL.md` returns nothing inside the Mode: Convert
  section (the `has_djvutxt` page-count guard in Step 3a and the status-report lines outside
  Mode: Convert are expected to remain and are not matches for these patterns).
- Diff review confirms Steps 3c-3h are untouched.

---

### Phase 2: Surface gate rejections and hard failures as actionable operator messages [COMPLETED]

**Goal**: Make exit 3 (quality-gate rejection) and exit 1/2 (hard conversion failure) skip the file
with a visible, reasoned message — and make those files appear in Convert Step 4's completion
summary. This phase carries the task's hard constraint: a rejection must never become a silent skip
or an index entry.

**Tasks**:
- [x] In the Step 3b block from Phase 1, add the `convert_exit -eq 3` branch: extract the reason
      with `gate_reason=$(grep -m1 'QUALITY GATE FAILED' "$convert_stderr" 2>/dev/null || echo "QUALITY GATE FAILED (reason unavailable)")`,
      echo an operator-facing line naming the file and the reason, append the entry to a
      `gate_failed_entries` array, clean up both temp paths, and `continue` to the next target. *(deviation: altered — written together with Phase 1's delegated call in one edit since both branch off the same `if convert_exit -eq 0/3/else` statement; behavior matches the plan exactly, only the edit sequencing differs)*
- [x] Add the `convert_exit -ne 0` (i.e. 1 or 2) branch: echo the failure with its exit code, pipe
      `convert_stderr` through `sed 's/^/  /'` to stderr so the engine-tier reason is visible,
      append to a `convert_failed_entries` array, clean up, and `continue`.
- [x] Verify by reading the control flow that both `continue` statements exit the per-file loop
      **before** Step 3c — no chunk files, no `AskUserQuestion` prompt, no `index.json` write, no
      `literature-chunk.sh` call is reachable for a rejected or failed file.
- [x] Initialize `gate_failed_entries=()` and `convert_failed_entries=()` before the Convert Step 3
      target loop so they accumulate across files.
- [x] Extend Convert Step 4's `**Skipped Files**:` completion-summary template (currently near line
      1233) with two new rendered categories: `{file} — QUALITY GATE FAILED: {reason}` and
      `{file} — conversion failed (exit {code}): {reason}`, alongside the existing djvutxt/no-text
      lines.
- [x] Add one sentence to the Convert Step 4 summary template stating explicitly that gate-rejected
      files were **not** written to `index.json` and were not chunked, so the operator cannot read
      a skip as a success.

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the Convert Step 4 completion-summary template with its
`**Skipped Files**:` list is at `SKILL.md` ~1218-1236 and is the only operator-facing summary for
Mode: Convert. Confirm by `grep -n 'Skipped Files' SKILL.md` and by checking no second convert
summary template exists between `## Mode: Convert` and `## Mode: Index`.

**Files to modify**:
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` — Step 3b exit-code
  branches; Convert Step 3 loop-preamble array init; Convert Step 4 summary template

**Verification**:
- `bash -n` on the extracted Step 3b fence still passes with all three exit branches present.
- Manual read-through of the loop confirms the exit-3 path cannot reach Step 3c or Step 3g.
- The rendered summary template names gate rejections distinctly from djvutxt-missing skips.

---

### Phase 3: Loosen Convert Step 2's pdftotext hard gate [COMPLETED]

**Goal**: Remove the now-incorrect hard error that aborts Mode: Convert when `pdftotext` is absent.
After Phase 1, `pdftotext` is only reachable via an explicit `LITERATURE_CONVERTER=pdftotext`
override that Mode: Convert never sets, so a machine with a working PyMuPDF stack but no
poppler-utils would be wrongly blocked.

**Tasks**:
- [x] Locate `### Convert Step 2: Check Tool Availability` (currently ~741-748) and replace the
      `exit 1` hard error with either removal of the check or a non-fatal informational line
      (recommended: drop the check entirely and let `literature-convert.sh`'s exit 2 carry a genuine
      all-tiers-failed condition, which is exactly what `literature-ingest.sh` does with no
      equivalent pre-check).
- [x] Leave the `has_djvutxt` checks alone — Step 3a's page-count guard and the soft-skip still
      need `djvutxt`, and `literature-convert.sh`'s DJVU path still depends on it.
- [x] If Convert Step 2 becomes empty after the removal, either delete the now-vacant step and
      renumber nothing (the step headings are prose anchors, not indices consumed by a script) or
      replace its body with the informational tool-availability echo; pick one and note which in the
      commit message. *(completed: chose the informational-echo replacement, keeping the `### Convert Step 2` heading as an anchor)*
- [x] Confirm `has_pdftotext` is still computed near line 73 for the status/scan report lines (185,
      248, 323) that legitimately display it — do not remove the variable itself.

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts exactly one `exit 1` hard gate on `has_pdftotext` exists,
in Convert Step 2 at ~744-748, and that the other four `has_pdftotext` references (~73, 185, 248,
323) are display-only. Confirm by `grep -n 'has_pdftotext' SKILL.md` and reading each hit before
editing.

**Files to modify**:
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` — Convert Step 2

**Verification**:
- `grep -n 'pdftotext not found' SKILL.md` returns nothing.
- `grep -n 'has_pdftotext' SKILL.md` shows only the definition and the display-only report lines.

---

### Phase 4: Update the Error Handling section to the delegated failure contract [NOT STARTED]

**Goal**: Bring the documented error contract in sync with the behavior Phases 1-3 produce, so the
skill's own documentation no longer describes inline-extraction failure modes that can no longer
occur.

**Tasks**:
- [ ] Replace the `- **pdftotext missing**: Hard error for convert mode on PDF files` bullet
      (currently ~2468) — after Phase 3 this is no longer true; state that conversion tier
      availability is `literature-convert.sh`'s concern and surfaces as its exit 2.
- [ ] Replace the `- **Empty pdftotext output**` bullet (~2470) with the two real delegated failure
      modes: quality-gate rejection (exit 3 -> skip with the gate's own reason, no index entry) and
      engine-tier exhaustion (exit 1/2 -> skip with the engine reason).
- [ ] Keep the `- **djvutxt missing**` bullet, adjusting its wording only if Phase 3's outcome
      changed the guard's location — the DJVU prerequisite itself is unchanged.
- [ ] Add one bullet stating the invariant explicitly: a gate-rejected document is never written to
      `index.json` and never chunked, and Mode: Convert reports it in the Skipped Files summary.

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: This phase asserts the three stale bullets sit at `SKILL.md` ~2468-2470 under
`## Error Handling`. Confirm by `grep -n 'pdftotext missing\|Empty pdftotext output\|djvutxt missing' SKILL.md`;
this is a prose-only region with no bash fence, so the diff must contain no executable lines.

**Files to modify**:
- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` — `## Error Handling`
  section

**Verification**:
- Diff read-through confirms every changed hunk is inside the prose bullet list (no bash fence
  crossed).
- No remaining bullet in `## Error Handling` describes `pdftotext` as a Mode: Convert prerequisite.

---

### Phase 5: Deploy, static duplicate-implementation check, and live acceptance verification [NOT STARTED]

**Goal**: Prove the three stated acceptance criteria against the real system, not against the
source text alone.

**Tasks**:
- [ ] Regenerate the `.claude/` deploy artifact from the source store so a live `/literature <path>`
      run exercises the edited skill. Do NOT hand-edit `.claude/extensions/literature/**`; use the
      repository's normal deploy/reload path. If regeneration requires user action, stop and report
      that as the blocking step rather than editing the deploy tree.
- [ ] **Acceptance criterion 3 (static)**: confirm no second conversion implementation remains —
      run a scoped grep over the `## Mode: Convert` .. `## Mode: Index` span of the deployed and
      source `SKILL.md` for `pdftotext`/`djvutxt` extraction invocations; expect zero.
- [ ] **Acceptance criterion 1 (live)**: run `/literature <path>` against a known-bad document (a
      garbled/scanned PDF — the OCR-garbled scan class named in the task description is the model)
      and confirm: a visible `QUALITY GATE FAILED` message with a reason, the file listed under
      Skipped Files, **no** new `index.json` entry, and **no** chunk files written.
- [ ] Verify the negative half of criterion 1 mechanically: capture `index.json`'s entry count and
      the target chunk directory listing before and after the rejected run; both must be unchanged.
- [ ] **Acceptance criterion 2 (live)**: run `/literature <path>` against a clean, born-digital
      multi-column PDF and confirm from `literature-convert.sh`'s stderr metrics line that the
      `pymupdf4llm` engine tier ran (not `pdftotext`, not the fallback), and that the resulting
      markdown carries real `#`/`##` heading markers.
- [ ] Confirm the interactive path still works end to end on the successful run: chunk-boundary
      confirmation prompt, metadata prompts, `index.json` write, and `literature-chunk.sh` all
      behave as before.
- [ ] Record the observed engine tier, gate reason, and before/after index counts in the
      implementation summary as the evidence for each acceptance criterion.

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: full

**Commit Mode**: per-substep

**Files to modify**:
- None (verification phase). Any defect found here is fixed in the owning phase's file
  (`agent-system/extensions/literature/skills/skill-literature/SKILL.md`) and re-verified.

**Verification**:
- All three acceptance criteria demonstrated with recorded output, not asserted.
- If a suitable known-bad document is not available locally, force a rejection by pointing the
  conversion at a document the gate is known to fail, or construct a fixture from
  `agent-system/extensions/literature/scripts/tests/generate-test-fixtures.py`; do not mark this
  phase complete on the strength of the static check alone.

---

## Testing & Validation

- [ ] Every replaced bash fence in Mode: Convert passes `bash -n` when extracted.
- [ ] Scoped grep over the Mode: Convert section finds zero direct `pdftotext`/`djvutxt` extraction
      calls.
- [ ] Control-flow read-through confirms exit 3 and exit 1/2 both `continue` before Step 3c.
- [ ] Live `/literature <path>` on a known-bad document: visible gate rejection, no index entry, no
      chunk files.
- [ ] Live `/literature <path>` on a clean multi-column PDF: `pymupdf4llm` tier reported, headings
      present, interactive prompts and index write unchanged.
- [ ] `bash agent-system/extensions/literature/scripts/tests/test-literature-convert.sh` still
      passes (this task changes no script it covers; a regression here means something out of scope
      was touched).

## Artifacts & Outputs

- `agent-system/extensions/literature/skills/skill-literature/SKILL.md` — modified: Convert Step 2
  (tool gate loosened), Convert Step 3b (delegated + exit-code branches), Convert Step 3 loop
  preamble (failure arrays), Convert Step 4 (summary categories), `## Error Handling` (updated
  contract).
- Regenerated `.claude/extensions/literature/skills/skill-literature/SKILL.md` (deploy artifact,
  produced by the deploy path, never hand-edited).
- `specs/106_route_skill_literature_convert_through_gated_pipeline/summaries/01_*-summary.md` —
  implementation summary recording the acceptance evidence from Phase 5.

## Rollback/Contingency

All changes are confined to one source-store file. Rollback is `git revert` of the phase commits
(or `git checkout HEAD~n -- agent-system/extensions/literature/skills/skill-literature/SKILL.md`)
followed by a deploy regeneration. Because the phases are committed per-substep and each phase is
independently meaningful, a partial rollback is viable: Phases 3 and 4 can be reverted alone
without disturbing the Phase 1/2 delegation, but Phase 1 cannot be reverted while Phase 2's
exit-code branches remain — revert them together. No data migration, no state change, and no
already-indexed document is modified by any phase, so rollback carries no corpus risk.
