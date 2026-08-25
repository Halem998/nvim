# Implementation Plan: Task #78

- **Task**: 78 - briefing_coverage_resolution_failure_signal
- **Status**: [NOT STARTED]
- **Effort**: 5.5 hours
- **Dependencies**: None (predecessor schema-unification task already [COMPLETED])
- **Research Inputs**: specs/078_briefing_coverage_resolution_failure_signal/reports/01_coverage-resolution-failure-signal.md
- **Artifacts**: plans/01_coverage-resolution-failure-signal.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`literature-briefing.sh`'s `lit-coverage` marker derives `seg_count` from
`${#briefing_lines[@]}`, which only ever counts documents that *resolved*. Every resolution
failure funnels through one bare `continue` (repo-mode loop, `literature-briefing.sh:191-194`)
that increments nothing, so a briefing that dropped every primary source self-reports
`sparse=false`. A second, more severe instance sits at lines 294-297: total resolution failure
produces `exit 0` — no marker, no banner, no stdout at all.

The plan instruments that single skip site with a counter plus a `skipped_doc_ids` array, makes
the total-failure case fall through to the shared marker/banner block instead of exiting
silently, extends the marker with `requested=`/`resolved=`/`skipped=`/`skip_rate=` appended
strictly *after* the existing fields, folds a new `LITERATURE_SKIP_RATE_THRESHOLD` rule into the
**existing** `sparse` boolean (rather than inventing a second, unconsumed flag), surfaces the
skipped `doc_id`s in an `## Unresolved Documents` body section, documents the threshold policy,
and adds a Section G regression test asserting a deliberately-unresolvable `doc_id` drives the
marker to report the failure.

### Research Integration

Four findings from the research report shape the phase structure directly:

1. **Single generic skip site.** Lines 191-194 are the *only* `continue` in the repo-mode loop,
   so instrumenting there (rather than enumerating failure causes) satisfies "must fire for any
   future resolution failure from any cause" structurally. Phase 1 targets exactly this.
2. **The line-294-297 silent full-failure exit must be fixed as part of this task**, not deferred.
   The simplest AC5 fixture (one unresolvable `doc_id`) would otherwise produce empty stdout with
   no marker to assert against. Phase 1 folds it in, gated strictly on `skip_count > 0` so the
   legitimately-empty sub-index guards (lines 150-168) keep exiting silently.
3. **Fold the skip signal into `sparse`, do not add a parallel flag.** Both existing consumers
   already grep `sparse=true`; reusing the boolean satisfies AC1 and AC3 simultaneously with zero
   edits to `lit-stage4a-flow.md` or `adhoc-navigation-directive.md`. A new flag nothing greps for
   would repeat the exact silent-signal failure this task exists to close.
4. **Section F of `test-lit-pipeline.sh` carries a header comment explicitly earmarking** "a
   companion coverage-marker regression" as the deferred item this task closes. Phase 4 adds
   Section G following Section F's fixture idiom verbatim (hand-built `index.json`, real-schema
   `.literature.db` from `literature-schema.sql`, `log_pass`/`log_fail`, its own
   `TEMP_LIT_DIR_G` cleaned by the existing `cleanup()` trap).

**One scoping correction carried forward from research into this plan**: making `sparse=true` fire
on a high repo-mode skip rate changes what the marker *says*, but nothing downstream currently
re-prompts on a sparse *repo-mode* marker — both consumers poll only `mode=global`. The fix is
still fully justified (the marker must stop lying; the skipped IDs must be visible to the
*consuming agent*), but no phase in this plan claims it causes an automatic repo-mode re-prompt.
Wiring that would require editing `lit-stage4a-flow.md`'s `SUBINDEX_PRESENT`/`SPARSE_PROMPT_NEEDED`
branches and is explicitly a **non-goal** below.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied in the delegation context; ROADMAP.md not consulted.

## Goals & Non-Goals

**Goals**:

- Track resolution failures with a counter and a `doc_id` array at the single repo-mode skip site.
- Extend the `lit-coverage` marker with `requested=`/`resolved=`/`skipped=`/`skip_rate=` so a high
  skip rate cannot self-report `sparse=false`.
- Make total resolution failure emit a marker instead of exiting silently.
- Surface skipped `doc_id`s in the briefing **body** under `## Unresolved Documents`.
- Decide and document the threshold policy in `sparse-coverage.md`.
- Regression-test the failure path in `test-lit-pipeline.sh` Section G.
- Verify both existing marker consumers still behave correctly.

**Non-Goals**:

- Editing `lit-stage4a-flow.md` or `adhoc-navigation-directive.md`. AC3 requires they keep working
  *unchanged*; the design achieves that by construction.
- Wiring a repo-mode sparse re-prompt into Stage 4a's `SUBINDEX_PRESENT`/`SPARSE_PROMPT_NEEDED`
  branches (out of declared scope; see the scoping correction above).
- Touching `literature-lit-flag-resolve.sh` (Checkpoint 1). Its own header comment forbids
  duplicating the `doc_id`/`GLOBAL_INDEX` cross-reference ("Risk 4: counting duplication").
- Adding a global-mode skip site. Global-mode segments arrive pre-resolved; no per-item external
  lookup exists there that can fail.
- Any write to the deployed `.claude/**` tree.

## File Scope Widening (flag to orchestrator)

The declared `file_scope` names two files. The design requires two more, both consequences of
acceptance criteria the task itself states:

| File | Why required | Driven by |
|------|--------------|-----------|
| `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` | AC5 demands a regression test; Section F's header comment names this task as its intended home | AC5 |
| `agent-system/extensions/literature/index-entries.json` | `sparse-coverage.md`'s entry carries `line_count: 33`, which the AC4 edit invalidates; the extension's convention is to resync it | AC4 side-effect |

Neither is discretionary. The orchestrator should widen `file_scope` to four files.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| New marker fields break the two consumer greps | H | L | Append strictly after `threshold=T`; leave `mode=`, `seg_count=`, `sparse=` byte-for-byte adjacent and in original order. Phase 5 runs `lit-stage4a-flow.md`'s literal grep against real emitted markers |
| Full-failure fallthrough regresses the genuinely-empty-sub-index silent-exit contract | M | M | Gate the fallthrough strictly on `skip_count -gt 0`. The `entry_count -eq 0`, missing-file, and empty-`doc_ids` guards (lines ~150-168) are untouched and still `exit 0` unconditionally. Phase 4 adds an explicit assertion that an empty sub-index still produces empty stdout |
| Folding skip-rate into `sparse` changes existing global-mode output | M | L | The new disjunct can only fire when `skip_count -gt 0`, which never occurs in global mode (no skip site exists there). Structurally a no-op for `mode=global`; Phase 5 confirms empirically |
| `LITERATURE_SKIP_RATE_THRESHOLD` default chosen without calibration data | L | H | Document the choice and its rationale explicitly in `sparse-coverage.md` (AC4 requires this anyway). `50` is a conservative, clearly-stated starting point that will not flag a normal 1-of-4 partially-curated sub-index, not a precision-tuned value |
| Division by zero computing `skip_rate` when `requested_count` is 0 | M | M | Guard: emit `skip_rate=0` when `requested_count -eq 0`. Reachable in global mode with zero results, so it is a live path, not defensive padding |
| `set -u` trips on an unbound counter in global mode | M | M | Initialize `skip_count=0`, `requested_count=0`, and `skipped_doc_ids=()` **before** the mode branch, following the existing `query_error` precedent at line ~74 |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 2, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Instrument the skip path and end the silent full-failure exit [NOT STARTED]

**Goal**: `literature-briefing.sh` counts and records every repo-mode resolution failure, and a
run where *every* requested `doc_id` fails reaches the shared exit block instead of `exit 0`.

**Tasks**:

- [ ] Initialize `skip_count=0`, `requested_count=0`, and `skipped_doc_ids=()` before the
      `mode` branch (near the existing `query_error` default, ~line 74), so global mode does not
      trip `set -u` at the shared exit point.
- [ ] In repo mode, set `requested_count="${#doc_ids[@]}"` immediately after the `mapfile` at
      line ~167, before the empty-`doc_ids` guard.
- [ ] At the skip site (lines ~191-194), before the `continue`: increment `skip_count` and append
      `"$doc_id"` to `skipped_doc_ids`. Keep the existing stderr warning unchanged — stderr stays,
      the body/marker surfacing is additive.
- [ ] Replace the lines ~294-297 early `exit 0` with a guard that exits silently **only** when
      `${#briefing_lines[@]} -eq 0` *and* `skip_count -eq 0`; when `skip_count -gt 0`, fall through
      to the shared exit block.
- [ ] Set `header`, `coverage_mode="repo"`, `coverage_count="${#briefing_lines[@]}"` on the
      fallthrough path too (the total-failure case must not reach the shared block with an unset
      `header`).
- [ ] In global mode (~lines 379-380), set `requested_count="$seg_count"` so the marker's
      `requested=` field is meaningful there; `skip_count` stays 0.
- [ ] `bash -n` the script.

**Timing**: 1 hour

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts the repo-mode loop contains exactly **one** `continue`
skip site, and that the only silent-exit sites are the guards at ~150-168 and ~294-297. Confirm at
implementation time with `grep -n 'continue\|exit 0' literature-briefing.sh` before editing; if a
second skip site exists, instrument it identically rather than assuming the count.

**Files to modify**:

- `agent-system/extensions/literature/scripts/literature-briefing.sh` — add counters/array,
  instrument the skip site, convert the total-failure exit into a fallthrough

**Verification**:

- `bash -n agent-system/extensions/literature/scripts/literature-briefing.sh` exits 0.
- A sub-index whose entries are all unresolvable no longer produces empty stdout (marker block is
  reached). Marker *content* is Phase 2's concern; here only "stdout is non-empty" is asserted.
- A sub-index with `entries: []` (or a missing sub-index) still produces empty stdout — the
  untouched legitimately-empty guards.

---

### Phase 2: Extend the marker schema, the sparse rule, the banner, and the body section [NOT STARTED]

**Goal**: The marker carries the failure signal, a high skip rate flips the existing `sparse`
boolean, and skipped `doc_id`s appear in the briefing body.

**Tasks**:

- [ ] Add `LITERATURE_SKIP_RATE_THRESHOLD="${LITERATURE_SKIP_RATE_THRESHOLD:-50}"` alongside
      `LITERATURE_SPARSE_THRESHOLD` (~line 68), matching that variable's env-var-with-default idiom
      exactly.
- [ ] Compute `skip_rate` as an integer percentage in pure bash arithmetic
      (`skip_rate=$(( skip_count * 100 / requested_count ))`), guarded so `requested_count -eq 0`
      yields `skip_rate=0`. Match the codebase style of avoiding `awk`/`bc` where bash `(( ))`
      suffices.
- [ ] Extend the sparse rule to a disjunction: `sparse=true` when
      `coverage_count -lt LITERATURE_SPARSE_THRESHOLD` (existing rule, byte-for-byte unchanged)
      **OR** `skip_count -gt 0 && skip_rate -ge LITERATURE_SKIP_RATE_THRESHOLD` (new rule).
- [ ] Extend the marker line, appending the four new fields strictly **after** `threshold=T`:
      `<!-- lit-coverage mode=${coverage_mode} seg_count=${coverage_count} sparse=${sparse} threshold=${LITERATURE_SPARSE_THRESHOLD} requested=${requested_count} resolved=${coverage_count} skipped=${skip_count} skip_rate=${skip_rate} -->`
- [ ] Emit a new banner in the existing `[UNVERIFIED ...]` / `[DEGRADED RETRIEVAL ...]` /
      `[SPARSE COVERAGE ...]` family, immediately after the `[SPARSE COVERAGE ...]` block,
      fired whenever `skip_count -gt 0` — independent of whether the rate crossed the threshold,
      since a low-but-nonzero skip rate is still worth surfacing per AC1:
      `[SKIPPED SOURCES - N of M requested document(s) could not be resolved (P%); see "Unresolved Documents" below]`
- [ ] Add an `## Unresolved Documents` body section listing each entry of `skipped_doc_ids[]`,
      placed after the new banner and before the per-document entries, guarded by
      `${#skipped_doc_ids[@]} -gt 0` (the same conditional-section idiom used elsewhere in the
      shared block). Naturally omitted in global mode, where the array is always empty.
- [ ] `bash -n` the script.

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: this phase asserts the marker gains exactly **four** new fields and that the
shared exit block (~404-476) is the sole marker-formatting site for both modes. Confirm with
`grep -n 'lit-coverage' literature-briefing.sh` returning exactly one emission site before editing.

**Files to modify**:

- `agent-system/extensions/literature/scripts/literature-briefing.sh` — threshold var, `skip_rate`
  computation, sparse disjunction, marker fields, banner, body section

**Verification**:

- `bash -n` exits 0.
- Hand-run against a fixture with 2 requested / 1 skipped: marker shows `requested=2 resolved=1
  skipped=1 skip_rate=50` and `sparse=true` (via the new rule — pick a fixture where
  `coverage_count=1 < 3` would *also* trip the old rule, so additionally construct or reason
  through a case isolating the new disjunct; Phase 4 makes this a permanent assertion).
- Total-failure fixture: marker shows `seg_count=0 resolved=0 skipped=N sparse=true`.
- Global mode: marker shows `skipped=0 skip_rate=0`, and `mode=`/`seg_count=`/`sparse=`/`threshold=`
  are byte-for-byte identical to their pre-change values for the same input.
- Body contains `## Unresolved Documents` listing the skipped `doc_id`(s).

---

### Phase 3: Document the threshold policy [NOT STARTED]

**Goal**: `sparse-coverage.md` records the decision, the new env var, the marker's new fields, and
the rationale; the context index entry is resynced.

**Tasks**:

- [ ] Add a `LITERATURE_SKIP_RATE_THRESHOLD` bullet to `sparse-coverage.md`'s `## Mechanisms`
      section, mirroring the existing `LITERATURE_SPARSE_THRESHOLD` bullet's structure: env var,
      default `50` (percent), comparison direction (`>=`, unlike the absolute-count rule's strict
      `<`).
- [ ] Update the marker-shape line in that file to the full new schema, so the documented shape
      matches what the script emits.
- [ ] Add a short subsection stating the **threshold policy decision** explicitly: a skip rate at
      or above the threshold makes the briefing untrustworthy and forces `sparse=true` through the
      *existing* boolean rather than a distinct signal, because both marker consumers already poll
      `sparse=true` — a separate flag nothing greps for would reproduce the silent-degradation
      failure this change closes. Record that `50` is a conservative starting value chosen without
      calibration data, deliberately loose enough not to flag a normal partially-curated sub-index
      (e.g. 1 of 4 entries legitimately superseded).
- [ ] Note that `skip_count -gt 0` always emits the `[SKIPPED SOURCES ...]` banner and the
      `## Unresolved Documents` section even below threshold, so a low skip rate is visible without
      being treated as untrustworthy.
- [ ] Resync `index-entries.json`'s `project/literature/domain/sparse-coverage.md` entry:
      add `LITERATURE_SKIP_RATE_THRESHOLD` and `skip_rate` to `keywords`, refresh `summary` if the
      file's scope description no longer fits, and set `line_count` to the file's actual new length
      (`wc -l`).
- [ ] Validate the JSON parses (`jq . index-entries.json > /dev/null`).

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: this phase asserts `sparse-coverage.md`'s index entry currently declares
`line_count: 33`. Re-read the entry before editing and set the value from `wc -l` on the edited
file rather than from this number.

**Files to modify**:

- `agent-system/extensions/literature/context/project/literature/domain/sparse-coverage.md` — new
  threshold mechanism, updated marker shape, threshold-policy decision subsection
- `agent-system/extensions/literature/index-entries.json` — keywords and `line_count` resync

**Verification**:

- The marker shape documented in `sparse-coverage.md` matches the string the script emits,
  compared field-by-field against real Phase 2 output.
- `jq .` parses `index-entries.json`.
- `line_count` equals `wc -l < sparse-coverage.md`.
- No task-number references anywhere in either file (both live outside `specs/**`).

---

### Phase 4: Section G regression test [NOT STARTED]

**Goal**: A deliberately-unresolvable `doc_id` registered in a sub-index permanently drives the
marker to report the failure rather than `sparse=false`. This assertion is the point of the task.

**Tasks**:

- [ ] Add `section_g()` to `test-lit-pipeline.sh` following Section F's fixture idiom exactly:
      own `TEMP_LIT_DIR_G` declared alongside `TEMP_LIT_DIR_F` and removed in the existing
      `cleanup()` trap; hand-authored `index.json`; `.literature.db` built from the real
      `literature-schema.sql` (never a hand-rolled `CREATE TABLE`); symlinked script resolution
      relative to its own `SCRIPT_DIR`; `log_pass`/`log_fail`/`log_info` per assertion.
- [ ] **Partial-failure case**: sub-index with 2 `doc_id`s — one matching a real `index.json`
      entry, one absent from `index.json` entirely. Assert the marker reports `requested=2`,
      `resolved=1`, `skipped=1`, `skip_rate=50`, and `sparse=true`.
- [ ] Assert the body contains the skipped `doc_id` under an `## Unresolved Documents` heading.
- [ ] Assert the `[SKIPPED SOURCES ...]` banner is present.
- [ ] **Total-failure case**: sub-index whose sole entry is unresolvable. Assert stdout is
      non-empty, a marker is emitted, and it reports `seg_count=0 resolved=0 skipped=1
      sparse=true` — closing the "no marker at all" variant.
- [ ] **Negative control**: a sub-index with `entries: []` still produces empty stdout, confirming
      the legitimately-empty silent-exit contract was not regressed by Phase 1.
- [ ] Register `section_g` in `main()`'s `RUN_RUNTIME` block immediately after `section_f`, and add
      a `G - ...` line to the header comment's `Sections:` list.
- [ ] Update Section F's header comment, which currently defers "a companion coverage-marker
      regression" as out of scope, to point at Section G instead of describing it as deferred.
- [ ] Run `bash test-lit-pipeline.sh --runtime` and confirm a clean pass.

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: full

**Scope Hypothesis**: this phase asserts four assertion groups across three fixtures. Treat the
count as a floor, not a ceiling: if the partial-failure fixture's `resolved=1` also trips the old
absolute-count rule (`1 < 3`), add a fixture sized so the *new* disjunct is the sole cause of
`sparse=true` (e.g. 4 resolvable + 4 unresolvable → `resolved=4`, above the sparse threshold,
`skip_rate=50`). Without that, AC5's regression does not actually pin the new rule.

**Files to modify**:

- `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` — new `section_g()`, `main()`
  registration, `TEMP_LIT_DIR_G` cleanup, header-comment section list, Section F comment update

**Verification**:

- `bash agent-system/extensions/literature/scripts/test-lit-pipeline.sh --runtime` exits 0 with
  zero failures.
- Temporarily reverting the Phase 1 skip-counter increment makes Section G fail (the test actually
  detects the defect it targets, rather than passing vacuously). Restore afterward.

---

### Phase 5: Verify both marker consumers still behave correctly [NOT STARTED]

**Goal**: AC3 confirmed empirically, not by inspection — `lit-stage4a-flow.md`'s grep and
`adhoc-navigation-directive.md`'s two-checkpoint re-prompt still work with zero edits to either
file.

**Tasks**:

- [ ] Capture a real global-mode marker line from the edited script for both a `sparse=true` and a
      `sparse=false` input.
- [ ] Run `lit-stage4a-flow.md:203`'s literal grep — `grep -q 'lit-coverage mode=global
      .*sparse=true'` — against both captured lines. Assert it matches the sparse one and does not
      match the non-sparse one.
- [ ] Confirm the pre-change global-mode marker's `mode=`, `seg_count=`, `sparse=`, `threshold=`
      fields are byte-for-byte unchanged for identical input, by diffing markers from `git stash`
      / `git show HEAD:` of the original script against the edited one on the same fixture.
- [ ] Re-read `adhoc-navigation-directive.md:45-46` and confirm it states no independent grep of
      its own (it cites `lit-stage4a-flow.md` as source of truth); record that its contract is
      satisfied transitively by the grep check above.
- [ ] Confirm neither consumer file was modified: `git status --short` shows no changes under
      `agent-system/extensions/core/context/patterns/` or
      `agent-system/extensions/literature/context/project/literature/patterns/`.
- [ ] Re-run the full `test-lit-pipeline.sh --runtime` suite (Sections A-G) for a final green gate.
- [ ] Confirm no writes landed under `.claude/**` and no task-number references were introduced
      outside `specs/**`.

**Timing**: 0.5 hours

**Depends on**: 2, 4

**Verification Tier**: full

**Files to modify**:

- None. This phase is verification-only; any file change it provokes is a defect fix belonging to
  Phase 2 and must be recorded as such.

**Verification**:

- The literal Stage 4a grep matches a sparse global marker and rejects a non-sparse one.
- Diff of pre/post global-mode markers shows only appended fields after `threshold=T`.
- `git status --short` shows exactly four modified files, all under
  `agent-system/extensions/literature/`.
- Full runtime suite exits 0.

---

## Testing & Validation

- [ ] `bash -n` passes on `literature-briefing.sh` and `test-lit-pipeline.sh`.
- [ ] `jq .` parses `index-entries.json`.
- [ ] AC1: a partial-failure run reports the failure in the coverage marker
      (`requested=`/`resolved=`/`skipped=`/`skip_rate=`), not only on stderr.
- [ ] AC2: skipped `doc_id`s appear in the briefing body under `## Unresolved Documents`.
- [ ] AC3: `lit-stage4a-flow.md`'s literal grep and `adhoc-navigation-directive.md`'s contract
      still work, with both files unmodified.
- [ ] AC4: threshold policy documented in `sparse-coverage.md`, including the "folded into
      `sparse`, not a separate signal" decision and its rationale.
- [ ] AC5: Section G asserts a deliberately-unresolvable `doc_id` drives the marker to report the
      failure rather than `sparse=false`, and fails when the Phase 1 counter is reverted.
- [ ] Negative control: a genuinely empty/absent sub-index still exits silently.
- [ ] Global mode's existing marker fields are byte-for-byte unchanged.
- [ ] No writes under `.claude/**`; no task-number references outside `specs/**`.

## Artifacts & Outputs

- `agent-system/extensions/literature/scripts/literature-briefing.sh` — skip counters, non-silent
  total-failure path, extended marker, skip-rate sparse rule, `[SKIPPED SOURCES ...]` banner,
  `## Unresolved Documents` body section
- `agent-system/extensions/literature/context/project/literature/domain/sparse-coverage.md` —
  `LITERATURE_SKIP_RATE_THRESHOLD`, new marker schema, threshold-policy decision
- `agent-system/extensions/literature/index-entries.json` — resynced keywords and `line_count`
- `agent-system/extensions/literature/scripts/test-lit-pipeline.sh` — Section G regression test
- `specs/078_briefing_coverage_resolution_failure_signal/summaries/01_*-summary.md` — execution
  summary (written at implementation completion)

## Rollback/Contingency

All four files are tracked and each phase commits separately, so `git revert` of the phase commits
restores prior behavior cleanly. The highest-risk change is the marker schema: if either consumer
grep breaks, the minimal repair is to move the four new fields to the very end of the marker line
(leaving the original four fields as a byte-for-byte prefix), which is grep-compatible by
construction. If the total-failure fallthrough proves to regress a legitimately-empty case not
anticipated here, revert only that hunk — the counter instrumentation, the marker extension, and
the body section are independent of it and still satisfy AC1, AC2, and AC4 on the partial-failure
path.
