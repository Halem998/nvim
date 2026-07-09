# Implementation Plan: Fix fail-open classification in literature-fidelity-audit.sh

- **Task**: 839 - Fix fail-open classification in literature-fidelity-audit.sh
- **Status**: [NOT STARTED]
- **Effort**: 4.75 hours
- **Dependencies**: None (task #832 depends on THIS task and runs immediately after)
- **Research Inputs**: specs/839_fix_fidelity_audit_fail_open/reports/01_fidelity-audit-fail-open.md
- **Artifacts**: plans/01_fix-fidelity-audit-fail-open.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta

## Overview

`classify_dir()` in `.claude/scripts/literature-fidelity-audit.sh` fails OPEN: when the
proof-completeness signal cannot fire (`frac is None`) on a low-ratio, undisclosed document, it
silently stamps `provenance_fidelity="verified_conversion"` — asserting a positive finding the
audit never made. This plan introduces a distinct sixth enum value `unadjudicated` for that
branch (fail CLOSED), widens the two real downstream consumers so `unadjudicated` is not silently
trusted one script over, fixes a separate `chunk_*.md` double-counting defect that produces
spurious `word_ratio > 1` values, explicitly resolves a 4th live victim (`thomas_2003_reactive`),
re-stamps the live corpus honestly via `--write`, and corrects two stale report records.

Definition of done: `--dry-run` shows the 3 named victim dirs as `unadjudicated`; the two
legitimately-disclosed dirs and the low-adequacy dir keep their correct values; the 3 ratio>1
dirs collapse to ~0.9-1.0; `thomas_2003_reactive` resolves honestly via the disclosure branch;
`--write` is idempotent on a second run; and all consumers plus the two stale reports reflect the
six-value enum.

### Research Integration

This plan is built directly on `reports/01_fidelity-audit-fail-open.md`, which corrected the
original task description on four points, all reflected below:
1. `literature-build-index.sh` is NOT a consumer (zero references) — it is not touched. The real
   consumers are `literature-search.sh` (`QUARANTINED_FIDELITY_VALUES`, line 51) and
   `literature-briefing.sh` (`needs_fidelity_marker()`, line 107-112, an opt-in allowlist that
   would silently omit the warning banner for `unadjudicated`).
2. A 4th live victim exists: `thomas_2003_reactive` (ratio=0.5041, disclosed=False,
   proof_fraction=None), currently stamped `verified_conversion` via the same buggy branch on both
   its child entries (`thomas_2003_ch01`, `thomas_2003_ch03`).
3. The secondary `word_ratio > 1` defect is caused by `chunk_NNNN.md` files being double-counted
   in the `mds` glob (lines 298-301) — chunks are near-verbatim re-splits of the canonical `.md`.
   The fix is to exclude chunks from the glob, NOT to add an arbitrary upper-bound threshold. This
   changes `word_ratio` for MANY dirs, so the whole cohort must be re-verified, not just the 3
   flagged dirs.
4. The `frac is None` branch was verified live at lines 366-375 (offset ~1-2 lines from the task
   description due to intervening comments); the header enum contract is at lines 38-39; the
   `main()` population-summary tuple is at lines 423-424.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` provided in delegation context and no `roadmap_flag` set; ROADMAP alignment not
applicable to this task.

### thomas_2003_reactive Decision (named, load-bearing)

**Decision: Option A — add a factually accurate scope-disclosure banner so it resolves via the
legitimate disclosure branch (`disclosed=True`), becoming `verified_conversion` honestly.**

Reasoning: the delegation directs preferring fail-closed (`unadjudicated`, Option B) UNLESS the
research gives positive evidence the banner is factually warranted. The research supplies exactly
that: task #835's own audit (`specs/835_.../reports/01_provenance-fidelity-audit.md`, cohort table)
already adjudicated this directory as a legitimate partial conversion — "real theorem content,
garbled ligatures" — and explicitly recommended "adding an explicit scope banner." The filenames
(`thomas_2003_ch01`, `thomas_2003_ch03`) truthfully disclose that this is a scoped chapter subset.
A disclosure banner is therefore factually accurate, and resolving via the disclosure branch is an
ADJUDICATED path (identical to `doets_1987`/`libkin_2004_ch3_ch7`), not the fail-open hole this
task closes. This is consistent with "fail closed, never open": the positive resolution now rests
on a human-verified finding and an accurate disclosure, not on a signal that could not fire.

This decision is executed as a concrete step in Phase 4. If, on reading `disclosure_check()`, the
implementer finds the document cannot be made to disclose truthfully (e.g., the banner text would
misrepresent scope), the fallback is Option B (let it become `unadjudicated`) — this fallback MUST
be flagged in the summary, not taken silently.

### Interaction with task #832

Task #832 (`reconvert_and_validate_literature_corpus`) depends on this task and runs immediately
after. #832 was written to WORK AROUND this bug by treating the 3 unadjudicated dirs as
reconversion candidates; its cohort logic reads `provenance_fidelity`. Therefore the new
`unadjudicated` value must be present and correctly stamped in the live `index.json` (Phase 5)
BEFORE #832 runs. The research confirmed #832's artifacts do not hard-code the enum string set, so
no code change is required in #832 — only a cross-reference note (Phase 7).

## Goals & Non-Goals

**Goals**:
- Introduce `unadjudicated` as the sixth enum value, assigned by the `frac is None` branch instead
  of `verified_conversion` (fail closed).
- Update the enum contract at the script header from five values to six.
- Add `unadjudicated` to the `main()` population-summary tuple so its count appears in stderr output.
- Widen both real downstream consumers (`literature-search.sh` line 51,
  `literature-briefing.sh` line 107-112) so `unadjudicated` is quarantined from default search and
  gets the `--lit` warning banner.
- Fix the `chunk_*.md` double-count in the `mds` glob and re-verify the entire classification cohort.
- Explicitly resolve `thomas_2003_reactive` per Option A (disclosure banner).
- Re-stamp the live corpus via `--write`, confirming idempotency.
- Correct the two stale report records in #835's report.

**Non-Goals**:
- Do NOT add an arbitrary upper-bound `word_ratio` threshold — fix the glob root cause instead.
- Do NOT touch `literature-build-index.sh` (not a consumer).
- Do NOT modify task #832's plan/report code logic (only a cross-reference note).
- Do NOT change the legitimate `disclosed=True` branch or the `frac < 0.6` -> `unverified_summary`
  branch behavior.
- Do NOT re-run web research or reconvert any PDFs (that is #832's job).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Enum widened in producer but a consumer left silently trusting the new value | H | M | Phase 3 explicitly updates both real consumers with exact line numbers; Phase 6 verifies marker/quarantine behavior for `unadjudicated` |
| Glob fix silently changes classification of dirs beyond the 3 flagged ones | M | H | Phase 2 diffs the FULL `--dry-run` TSV before/after and re-audits the whole cohort, not just flagged dirs |
| `thomas_2003_reactive` resolved implicitly by the code fix instead of by explicit decision | M | M | Option A decision stated above and executed as a named Phase 4 step; fallback to Option B must be flagged, not silent |
| `--write` not idempotent if re-stamp depends on a hardcoded 5-value set elsewhere | M | L | Phase 6 runs `--write` twice and confirms the second run is a no-op |
| Disclosure banner for thomas_2003 misrepresents scope | M | L | Phase 4 reads `disclosure_check()` first; banner text must be factually accurate or fall back to Option B with a flag |
| #832 runs before `index.json` is re-stamped | H | L | Phase 5 re-stamps live corpus; plan documents the ordering dependency for the orchestrator |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4 | 1, 2 |
| 4 | 5 | 1, 2, 4 |
| 5 | 6 | 5 |
| 6 | 7 | 4, 6 |

Phases within the same wave can execute in parallel. Note Phases 1 and 2 both edit
`literature-fidelity-audit.sh`; Phase 2 is sequenced after Phase 1 to avoid edit conflict and
because whole-cohort re-verification needs both fixes present.

### Phase 1: Fix the primary fail-open branch and enum contract [COMPLETED]

**Goal**: Make the `frac is None` branch fail closed by assigning `unadjudicated`, and update the
enum contract documentation and the population summary so the sixth value is first-class.

**Tasks**:
- [x] In `.claude/scripts/literature-fidelity-audit.sh`, change the `frac is None` branch (line
      ~373, `result["provenance_fidelity"] = "verified_conversion"`) to assign `"unadjudicated"`.
      *(completed)*
- [x] Update the branch's explanatory comment (lines ~367-372) to state the new fail-closed
      rationale (the audit could not adjudicate: no numbered statements, undisclosed, low ratio ->
      `unadjudicated`, never `verified_conversion`). *(completed)*
- [x] Update the header enum contract (lines 38-39): "Five-value enum: ..." -> "Six-value enum:
      verified_conversion, unverified_summary, no_source_pdf, not_yet_converted,
      unverified_no_baseline, unadjudicated." *(completed)*
- [x] Add `"unadjudicated"` to the `main()` population-summary tuple (lines 423-424) so its count
      prints in the `--dry-run`/`--write` stderr summary.

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/literature-fidelity-audit.sh` - branch assignment, branch comment, header enum
  contract, population-summary tuple.

**Verification**:
```bash
# Header now advertises six values including unadjudicated
grep -n "Six-value enum" .claude/scripts/literature-fidelity-audit.sh
grep -n "unadjudicated" .claude/scripts/literature-fidelity-audit.sh
# Dry-run (report-only, never writes) shows the 3 named victims as unadjudicated
bash .claude/scripts/literature-fidelity-audit.sh --dry-run 2>/dev/null \
  | grep -E "fine_2012_guide-to-ground|fine_2012_counterfactuals-without-possible-worlds|venema_1991"
# Population summary prints an unadjudicated line
bash .claude/scripts/literature-fidelity-audit.sh --dry-run 2>&1 >/dev/null | grep "unadjudicated:"
```
Expect the 3 named dirs to show `unadjudicated`; `doets_1987`, `libkin_2004_ch3_ch7` remain
`verified_conversion`; `rabinovich_2014` remains `unverified_summary`.

---

### Phase 2: Fix chunk_*.md double-counting in the mds glob [COMPLETED]

**Goal**: Remove the `word_ratio > 1` artifact at its root cause by excluding `chunk_NNNN.md`
re-split files from the `mds` glob, then re-verify the ENTIRE classification cohort (the glob
change affects word_ratio for many dirs, not only the 3 flagged high-ratio dirs).

**Tasks**:
- [x] Capture a baseline full `--dry-run` TSV BEFORE the change:
      `bash .claude/scripts/literature-fidelity-audit.sh --dry-run > /tmp/claude-1000/audit-before.tsv 2>/dev/null`.
      *(completed: baseline captured after Phase 1's fix, before Phase 2's glob change)*
- [x] In the `mds` glob (lines 298-301), exclude files matching `^chunk_\d+\.md$`
      (case-insensitive), e.g. add `and not re.match(r"^chunk_\d+\.md$", e, re.IGNORECASE)` to the
      comprehension filter. Do NOT alter the `pdfs` glob. *(completed)*
- [x] Capture the AFTER TSV and diff it against the baseline to review every classification change
      across the whole cohort (not just the 3 flagged dirs). *(completed: full diff shows exactly
      5 rows changed — the 3 ratio>1 dirs collapsed to ~0.96-1.07, and 2 already-`unadjudicated`
      low-ratio dirs got lower (more honest) ratios with no classification change; population
      summary counts unchanged; no unexpected classification flips anywhere in the 97-dir cohort)*

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `.claude/scripts/literature-fidelity-audit.sh` - `mds` glob comprehension only.

**Verification**:
```bash
bash .claude/scripts/literature-fidelity-audit.sh --dry-run > /tmp/claude-1000/audit-after.tsv 2>/dev/null
# The 3 ratio>1 dirs now land at ~0.9-1.0
grep -E "fine_2010_some-puzzles-of-ground|fine_2012_pure-logic-of-ground|bacon_2018_broadest-necessity" /tmp/claude-1000/audit-after.tsv
# Review the full delta; confirm no dir flips to a WRONG classification
diff /tmp/claude-1000/audit-before.tsv /tmp/claude-1000/audit-after.tsv
```
Expect the 3 named ratio>1 dirs to move to ~0.9-1.04 and stay `verified_conversion`; any other
dir whose ratio changes must retain a defensible classification (spot-check against Phase 6
invariants).

---

### Phase 3: Widen the two real downstream consumers [COMPLETED]

**Goal**: Ensure `unadjudicated` is treated as a fidelity failure everywhere it is consumed, so it
is not silently trusted one script downstream — the same class of bug this task fixes.

**Tasks**:
- [x] In `.claude/scripts/literature-search.sh` line 51, add `unadjudicated` to
      `QUARANTINED_FIDELITY_VALUES` (currently `"unverified_summary unverified_no_baseline"` ->
      `"unverified_summary unverified_no_baseline unadjudicated"`). Update the adjacent comment if
      it enumerates the quarantined set. *(completed)*
- [x] In `.claude/scripts/literature-briefing.sh` `needs_fidelity_marker()` (lines 107-112), add
      `unadjudicated` to the allowlist case:
      `unverified_summary | unverified_no_baseline | unadjudicated) return 0 ;;`. Update the
      preceding comment (lines 103-105) which enumerates which values get the loud marker.
      *(completed)*
- [x] Confirm no code change is needed in `literature-search.sh`'s `!= 'verified_conversion'`
      banner logic or its `get_fidelity` fail-open reads (they already handle any new value); do
      not modify them. *(confirmed: line 861 uses `!= 'verified_conversion'`, fail-open by
      construction; `get_fidelity`/`load_fidelity_map` default missing entries to
      `unverified_summary`. No change made.)*

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/scripts/literature-search.sh` - `QUARANTINED_FIDELITY_VALUES` (line 51).
- `.claude/scripts/literature-briefing.sh` - `needs_fidelity_marker()` (lines 107-112).

**Verification**:
```bash
grep -n "unadjudicated" .claude/scripts/literature-search.sh
grep -n "unadjudicated" .claude/scripts/literature-briefing.sh
# needs_fidelity_marker returns 0 (true) for unadjudicated
bash -c 'source .claude/scripts/literature-briefing.sh 2>/dev/null; needs_fidelity_marker unadjudicated && echo MARKED || echo UNMARKED'
```
Expect `MARKED`. (If `source` triggers side effects, instead extract and eval the
`needs_fidelity_marker` function body, or assert the case line via grep.)

---

### Phase 4: Resolve thomas_2003_reactive via disclosure banner (Option A) [COMPLETED]

**Goal**: Execute the Option A decision — add a factually accurate scope-disclosure banner so
`thomas_2003_reactive` resolves via the legitimate `disclosed=True` branch as `verified_conversion`,
rather than falling through the (now `unadjudicated`) fail-closed branch.

**Tasks**:
- [x] Read `disclosure_check()` in `literature-fidelity-audit.sh` to determine exactly what
      triggers `disclosed=True` (it reads both `md_texts` and `index_summaries`). *(completed:
      `DISCLOSURE_RE` matches "selective conversion|extracted:?\s*chapter|truncated|excerpt|
      chapters?\s+\d+\s+and\s+\d+" against the combined text of `md_texts` + `index_summaries`)*
- [x] Add a factually accurate scope-disclosure banner in the mechanism `disclosure_check()`
      recognizes, matching the `hodkinson_2006` precedent (its `index.json` `.summary` phrasing,
      e.g. "...table of contents and introduction only; full chapter truncated"). Prefer the
      durable location: if disclosure is keyed off the source `.md` text, add the banner to both
      `~/Projects/Literature/sources/thomas_2003_reactive/*.md` source files; if keyed off the
      index summary, add disclosure language to the `.summary` fields of both `thomas_2003_ch01`
      and `thomas_2003_ch03` entries in `~/Projects/Literature/index.json`. The banner must
      truthfully state the scope (chapters 1 and 3; garbled ligatures; real theorem content).
      *(completed: added "Selective conversion: chapters 1 and 3 of the lecture notes only; some
      ligature/OCR garbling from the source PDF..." to both `.summary` fields via jq, atomic
      write, backup verified before edit)*
- [x] If the banner cannot be written truthfully, fall back to Option B (leave undisclosed -> it
      becomes `unadjudicated`) and FLAG this deviation for the summary — do not take it silently.
      *(not applicable: banner written truthfully, Option A succeeded — confirmed via --dry-run:
      thomas_2003_reactive shows verified_conversion, disclosed=True; no fallback taken)*

**Timing**: 0.75 hours

**Depends on**: 1, 2

**Files to modify**:
- `~/Projects/Literature/sources/thomas_2003_reactive/*.md` OR `~/Projects/Literature/index.json`
  (`.summary` of `thomas_2003_ch01` / `thomas_2003_ch03`) - whichever `disclosure_check()` reads.

**Verification**:
```bash
# thomas_2003_reactive now resolves via the disclosure branch (disclosed=True) as verified_conversion
bash .claude/scripts/literature-fidelity-audit.sh --dry-run 2>/dev/null \
  | grep "thomas_2003_reactive"
```
Expect `verified_conversion` with `disclosed=True` (Option A). If the fallback was taken, expect
`unadjudicated` with `disclosed=False` and a flagged note.

---

### Phase 5: Re-stamp the live corpus via --write [COMPLETED]

**Goal**: Persist the honest classifications into `~/Projects/Literature/index.json` so downstream
consumers (and task #832) read the corrected `provenance_fidelity` values.

**Tasks**:
- [x] Run `bash .claude/scripts/literature-fidelity-audit.sh --write` once to re-stamp. *(completed:
      backup created and verified at index.json.bak.20260709-232631; 153 entries stamped, 14
      changed, 139 unchanged; population summary: verified_conversion 39, unadjudicated 3)*
- [x] Confirm via `jq` that the 3 named victim child entries now carry `unadjudicated`, and that
      `thomas_2003_ch01`/`thomas_2003_ch03` carry the Phase-4 outcome (Option A: `verified_conversion`).
      *(completed: confirmed via jq, all correct)*

**Timing**: 0.5 hours

**Depends on**: 1, 2, 4

**Files to modify**:
- `~/Projects/Literature/index.json` - re-stamped `provenance_fidelity` fields (via the script).

**Verification**:
```bash
jq -r '.entries[] | select(.path|test("sources/(fine_2012_guide-to-ground|fine_2012_counterfactuals-without-possible-worlds|venema_1991)/")) | "\(.id)\t\(.provenance_fidelity)"' ~/Projects/Literature/index.json
jq -r '.entries[] | select(.id|test("^thomas_2003_ch0(1|3)$")) | "\(.id)\t\(.provenance_fidelity)"' ~/Projects/Literature/index.json
```
Expect the 3 named victims -> `unadjudicated`; `thomas_2003_ch01`/`ch03` -> `verified_conversion`
(Option A).

---

### Phase 6: Verification contract (explicit) [NOT STARTED]

**Goal**: Assert every invariant from the task's verification contract in one adversarial pass,
including `--write` idempotency.

**Tasks**:
- [ ] Run `--dry-run` and confirm ALL of the following in one TSV:
  - the 3 named victim dirs show `unadjudicated`;
  - `doets_1987` (ratio 0.2378) and `libkin_2004_ch3_ch7` (ratio 0.0187) still
    `verified_conversion` via the disclosure branch;
  - `rabinovich_2014` still `unverified_summary` (proof_fraction 0.545 < 0.6);
  - the 3 ratio>1 dirs (`fine_2010_some-puzzles-of-ground`, `fine_2012_pure-logic-of-ground`,
    `bacon_2018_broadest-necessity`) now show ratios ~0.9-1.0;
  - `thomas_2003_reactive` shows the Phase-4 outcome (Option A: `verified_conversion`,
    `disclosed=True`).
- [ ] Run `--write` a SECOND time and confirm the run is a no-op (idempotent) — no `index.json`
      diff, or the script's own "no changes" report.

**Timing**: 0.75 hours

**Depends on**: 5

**Files to modify**:
- None (verification only; `--dry-run` is report-only and never writes `index.json`).

**Verification**:
```bash
bash .claude/scripts/literature-fidelity-audit.sh --dry-run 2>/dev/null | \
  grep -E "fine_2012_guide-to-ground|fine_2012_counterfactuals-without-possible-worlds|venema_1991|doets_1987|libkin_2004_ch3_ch7|rabinovich_2014|fine_2010_some-puzzles-of-ground|fine_2012_pure-logic-of-ground|bacon_2018_broadest-necessity|thomas_2003_reactive"
# Idempotency: capture, re-write, diff
cp ~/Projects/Literature/index.json /tmp/claude-1000/index-before-2nd-write.json
bash .claude/scripts/literature-fidelity-audit.sh --write >/dev/null 2>&1
diff /tmp/claude-1000/index-before-2nd-write.json ~/Projects/Literature/index.json && echo "IDEMPOTENT"
```
Expect all invariant rows correct and `IDEMPOTENT`.

---

### Phase 7: Correct stale report records and cross-references [NOT STARTED]

**Goal**: Bring the documentation record in line with the realized-and-fixed state.

**Tasks**:
- [ ] In `specs/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md`:
  - Update the "accepted residual risk" bullet (the `frac is None` gap) to state the risk was
    REALIZED (3-4 real victims found), and reference task #839 as the fix that introduced
    `unadjudicated` (fail closed).
  - Update the `thomas_2003_reactive` recommendation ("recommend adding an explicit scope banner")
    to mark it IMPLEMENTED via Option A (or superseded by `unadjudicated` if the Phase-4 fallback
    was taken).
- [ ] Add a one-line cross-reference note in this task's summary (at implement time) that #832's
      cohort logic now reads the corrected `unadjudicated` value; no code change was needed in #832.
- [ ] (Optional, low-cost) Add a short note to `.claude/context/project/literature/patterns/`
      documenting that `chunk_NNNN.md` files are index-only re-splits of the canonical `.md` and
      must be excluded from whole-document word counts (per the research's Context Extension
      Recommendation), and update the one prose reference to the enum in
      `.claude/context/project/literature/patterns/zotero-pdf-resolution.md` from five to six values.

**Timing**: 0.75 hours

**Depends on**: 4, 6

**Files to modify**:
- `specs/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md`
- (Optional) `.claude/context/project/literature/patterns/*.md` (chunk convention note; enum count).

**Verification**:
```bash
grep -n "839\|realized\|unadjudicated" specs/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md
grep -n "thomas_2003" specs/835_literature_corpus_provenance_fidelity_audit/reports/01_provenance-fidelity-audit.md
```
Expect the residual-risk bullet and the thomas_2003 recommendation to reflect the fixed state.

## Testing & Validation

- [ ] `--dry-run` shows the 3 named victim dirs as `unadjudicated`.
- [ ] `doets_1987` and `libkin_2004_ch3_ch7` remain `verified_conversion` via the disclosure branch.
- [ ] `rabinovich_2014` remains `unverified_summary` (proof_fraction 0.545 < 0.6).
- [ ] The 3 ratio>1 dirs show ratios ~0.9-1.0 after the glob fix; whole-cohort diff reviewed.
- [ ] `thomas_2003_reactive` shows the Phase-4 Option-A outcome (`verified_conversion`,
      `disclosed=True`), or a flagged Option-B fallback.
- [ ] Header enum contract lists six values; population summary prints an `unadjudicated:` count.
- [ ] `literature-search.sh` quarantines `unadjudicated`; `literature-briefing.sh` marks it.
- [ ] `--write` re-stamps the live corpus and is idempotent on a second run.
- [ ] #835 report's residual-risk bullet and thomas_2003 recommendation are corrected.

## Artifacts & Outputs

- `plans/01_fix-fidelity-audit-fail-open.md` (this plan)
- `summaries/01_fix-fidelity-audit-fail-open-summary.md` (at implement time)
- Modified: `.claude/scripts/literature-fidelity-audit.sh`,
  `.claude/scripts/literature-search.sh`, `.claude/scripts/literature-briefing.sh`
- Re-stamped: `~/Projects/Literature/index.json` (+ thomas_2003 disclosure edit)
- Corrected: `specs/835_.../reports/01_provenance-fidelity-audit.md`

## Rollback/Contingency

- Script edits are localized; revert via `git checkout -- .claude/scripts/literature-fidelity-audit.sh
  .claude/scripts/literature-search.sh .claude/scripts/literature-briefing.sh`.
- `~/Projects/Literature/index.json` is outside the repo: before Phase 5, back it up
  (`cp ~/Projects/Literature/index.json /tmp/claude-1000/index-backup.json`); restore from that
  backup if the re-stamp is wrong. `--write` is idempotent, so re-running after a corrected script
  is safe.
- The thomas_2003 disclosure edit is a small, reversible text/summary change; if Option A proves
  unwarranted, remove the banner and let it become `unadjudicated` (Option B), flagging the change.
