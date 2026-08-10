# Implementation Plan: Task #1015

- **Task**: 1015 - Re-check settings.local.json deploy merge for content loss before any fix effort
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: `specs/1015_recheck_settings_local_merge_content_loss/reports/01_recheck-settings-local-merge.md`
- **Artifacts**: plans/01_close-out-merge-recheck.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This is a **close-out plan, not a fix plan**. The verification work this task existed to perform
is complete: the research report states a reproduction rate of 0 of 12 wipe-pairs (24 `--wipe`
invocations against an isolated scratch copy) in this round, 0 of 15 cumulative, with a validated
positive-control structural detector and no correlation across six pre-existing-state variants.
The task's stated ACCEPTANCE -- "a stated reproduction rate over a named sample size" -- is
therefore already satisfied by the report. What remains is bookkeeping: close the error record
through the sanctioned writer, put the rate somewhere a future reader will actually find it,
correct one now-falsified claim in the deploy documentation, and take an explicit stated position
on the two residual hypotheses rather than letting them dangle.

**Merge logic is not touched.** Reproduction was never established; the task forbids a fix, and
nothing in this plan edits `merge.lua`, `settings_backup.lua`, `init.lua`, `deploy-headless.sh`,
or any other merge/deploy code path.

### Research Integration

Four findings from the report drive the phases below:

1. **0/12 this round, 0/15 cumulative**, every observed diff pure key/array reordering
   (Lua `pairs()` nondeterminism), never a dropped block. Detector validated with a positive
   control before "0 dropped" was trusted. -> Phases 1, 2, 3.
2. **Strong candidate root cause identified**: commit `1692e33e8` moved settings restoration to
   *before* the extension reload loop in `manager.regenerate`; the pre-fix ordering would produce
   exactly the observed shape (dropped `hooks.PreToolUse` + dropped `mcpServers`). The original
   single observation is plausibly a pre-fix sighting, not an unexplained intermittent defect.
   -> Phases 1, 3.
3. **Residual untested hypothesis**: the `specs/.deploy-lock` mutex is fail-open/non-blocking, so
   genuinely concurrent access was never exercised by strictly serial sampling. -> Phase 3.
4. **A documented claim is now falsified in its literal form**: `regeneration-is-manual-only.md`
   asserts `--wipe` preserves `settings.local.json` "byte-identically" across the deletion. Twelve
   pairs show it is preserved *semantically* (`jq -S` identical) but reordered at the byte level in
   every single pair. -> Phase 2.

### Constraint discovered during planning (binding on Phase 1)

The task description asks to "downgrade the recorded severity." **The sanctioned writer cannot do
that.** `agent-system/extensions/core/scripts/errors-append.sh update` accepts exactly `--id`,
`--fix-status`, `--fixed-date`, and `--fix-task`; its merged-document validator re-checks the
seven required fields but provides no path to mutate `severity`. The plan therefore closes the
record (`--fix-status fixed --fix-task 1015`) rather than downgrading it. A closed record is out
of triage regardless of its historical severity stamp, so closure supersedes downgrading and
delivers the same practical outcome. Hand-editing `specs/errors.json` to change `severity` is
**forbidden** -- the file has a `flock`-disciplined validated writer and a formal schema, and a
hand edit bypasses both.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in the delegation context and no ROADMAP.md was loaded.

## Goals & Non-Goals

**Goals**:
- Close `err_1786350581208_23mAsn` through `errors-append.sh update`, with the fixing task
  recorded, so it stops appearing as an open high-severity item.
- Record the 0/15 cumulative reproduction rate and the named sample size durably, in a deliverable
  a future reader of the deploy machinery will encounter without knowing this task ever existed.
- Correct the now-falsified "byte-identically" claim in `regeneration-is-manual-only.md` to the
  accurate "semantically identical, byte-level reordering observed in every pair."
- Take and write down an explicit position on the concurrency residual and on
  `err_1786350581240_JyztWt`, so neither is silently dropped.

**Non-Goals**:
- **Any change to merge, backup, restore, or deploy logic.** Reproduction was not established.
- Extending `errors-append.sh` with a `--severity` mutation. Closure makes it unnecessary, and
  widening a validated writer to serve one bookkeeping wish is scope creep with a schema blast
  radius.
- Fixing the ordering nondeterminism itself (stable key ordering at generation time). That stays
  open under its own record -- see Phase 3 for the stated position.
- Running further wipe-pair sampling. 15 cumulative pairs is the sample; more serial pairs would
  add nothing the report does not already establish.
- Repairing the stale `summary` field on the `regeneration-is-manual-only.md` index entry (it
  still says the deployment path has "no headless/CI equivalent," contradicted by the file's own
  `## The Headless Path (verified)` section). Real, but unrelated to this close-out and better
  handled where index-entry summaries are audited as a class.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer reads "downgrade severity" from the task description and hand-edits `specs/errors.json` | M | M | Phase 1 opens by re-reading the `update` argument parser and confirming the constraint before writing; hand-editing is called out as forbidden in Overview, Phase 1 tasks, and Rollback |
| Implementer treats this as a merge-logic fix task and edits `merge.lua`/`init.lua` | H | L | Stated in Overview and Non-Goals; Phase 3's Testing gate greps the working diff for any `lua/neotex/plugins/ai/shared/extensions/` path |
| Deliverable edit cites a task number and trips the write-time PreToolUse guard | L | M | Phase 2 references durable anchors only (report path, commit SHA, section headings); the report path itself is safe -- `TASK_PATTERN` requires a literal `task[sep]N`, which `specs/1015_.../` does not contain |
| Editing an indexed context file leaves `line_count` stale in `index-entries.json` | L | H | Phase 2 runs `generate-context-line-counts.sh --check`, then `--write` on drift |
| Concurrency residual gets closed by omission rather than by decision | M | M | Phase 3 exists solely to state the position in writing, in both a deliverable and a decision record |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Close the content-loss error record via the sanctioned writer [COMPLETED]

**Goal**: `err_1786350581208_23mAsn` carries `fix_status: "fixed"` with `fix_task: 1015` and a
`fixed_date`, written by `errors-append.sh update` and by nothing else.

**Tasks**:
- [x] Re-read the `update` subcommand's argument parser in
      `agent-system/extensions/core/scripts/errors-append.sh` and confirm in the implementation
      summary that `--severity` is not an accepted flag. If it *is* accepted (contradicting this
      plan's finding), prefer `--severity low` and note the divergence -- do not hand-edit either
      way. *(completed: confirmed -- the `update` case block at lines 306-315 accepts exactly
      --id/--fix-status/--fixed-date/--fix-task; --severity falls into the `*)` unknown-argument
      branch and errors)*
- [x] Run the closure through the deployed writer:
      `bash .claude/scripts/errors-append.sh update --id err_1786350581208_23mAsn --fix-status fixed --fix-task 1015`
      *(completed)*
- [x] Re-read the record with `jq` and confirm `fix_status`, `fix_task`, and `fixed_date` landed
      and that `message`, `context`, `severity`, and `recovery` are byte-unchanged. *(completed)*
- [x] Confirm `err_1786350581240_JyztWt` was NOT touched (it stays `unfixed` -- see Phase 3).
      *(completed)*
- [x] Do NOT edit `specs/errors.json` with `Write`, `Edit`, `sed`, or an inline `jq` redirect.
      *(completed: no hand-edit performed, writer only)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This plan asserts that `errors-append.sh update` supports exactly four flags
(`--id`, `--fix-status`, `--fixed-date`, `--fix-task`) and cannot mutate `severity`. Confirm at
implementation time by reading the `while [ $# -gt 0 ]` case block in the `update` section of the
script before running any command; the branch taken above depends on that reading.

**Files to modify**:
- `specs/errors.json` - one record's `fix_status`/`fixed_date`/`fix_task`, via the writer only

**Verification**:
- `jq '.errors[] | select(.id=="err_1786350581208_23mAsn")' specs/errors.json` shows
  `fix_status: "fixed"`, `fix_task: 1015`, and a populated `fixed_date`
- `jq -e '.errors[] | select(.id=="err_1786350581240_JyztWt") | .fix_status == "unfixed"' specs/errors.json`
  still passes
- `jq empty specs/errors.json` parses clean

---

### Phase 2: Record the reproduction rate durably in the deploy documentation [COMPLETED]

**Goal**: A reader of `regeneration-is-manual-only.md` learns, without knowing this task ever ran,
(a) that `--wipe` round-trip fidelity for `settings.local.json` was empirically measured, (b) the
sample size and rate, and (c) that the preservation is semantic, not byte-level.

**Tasks**:
- [x] In `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`, correct
      the claim in `## The Headless Path (verified)` that `--wipe` preserves `settings.local.json`
      and `.syncprotect`-listed paths "byte-identically." Replace with the accurate statement:
      preserved **semantically** (`jq -S` value-for-value identical), with key/array reordering
      observed at the byte level, attributable to Lua `pairs()` iteration nondeterminism.
      *(completed)*
- [x] Add a short subsection under `## Merge Semantics That Regeneration Cannot Fix` -- suggested
      heading `### Round-Trip Fidelity of settings.local.json (measured)` -- stating: 24 `--wipe`
      invocations across 12 pairs against an isolated scratch copy, plus 3 pairs from an earlier
      round, produced 0 dropped keys, array elements, or blocks (15 pairs cumulative); every
      difference was ordering-only; six pre-existing-state variants (baseline, extra permissions,
      reversed key order, ~2.5x bloated, minimal, pre-seeded duplicate `PreToolUse` matcher)
      showed no correlation with loss; the structural presence detector was validated against a
      positive control before its zero-result was trusted. *(completed)*
- [x] In the same subsection, record the **known limitation** verbatim in substance: the sampling
      was strictly serial, and the `specs/.deploy-lock` mutex is fail-open/non-blocking by design
      (the same acquire/warn-and-proceed shape as `specs/.commit-lock`), so a genuinely concurrent
      `--wipe` racing another `--wipe` or a concurrent hand-edit is **outside** what this
      measurement covers. *(completed)*
- [x] Cite durable anchors only: the report path
      `specs/1015_recheck_settings_local_merge_content_loss/reports/01_recheck-settings-local-merge.md`,
      commit `1692e33e8`, and named section headings. **No task-number citations** -- no
      `task 1015`, `task 996`, or `(task N)` phrasing anywhere in this file. *(completed: verified
      via check-task-references.sh, 0 occurrences)*
- [x] Optionally add the new subsection to `## Related Documentation` if a cross-reference helps.
      *(completed: added report-path cross-reference)*
- [x] Run `bash .claude/scripts/generate-context-line-counts.sh --check`; if
      `patterns/regeneration-is-manual-only.md` reports drift, run `--write`. *(completed: drift
      found 159 declared vs 210 actual, corrected via --write)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This plan asserts exactly one file needs editing in the source store
(`agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`, currently 159
lines, indexed in `agent-system/extensions/core/index-entries.json` with `line_count: 159`) and
that the falsified "byte-identically" claim appears there once. Confirm at implementation time
with `grep -rn "byte-identical" agent-system/extensions/` -- if the claim is restated elsewhere
(e.g. in a merge-source, a test comment, or `batch-orchestration-guardrails.md`), correct every
occurrence and report the true count in the summary rather than silently fixing only the first.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - correct the
  byte-identical claim; add the measured round-trip-fidelity subsection with the known limitation
- `agent-system/extensions/core/index-entries.json` - `line_count` refresh only, and only if
  `--check` reports drift

**Verification**:
- `grep -n "byte-identical" agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
  returns no surviving assertion that `settings.local.json` survives byte-identically
- `bash .claude/scripts/check-task-references.sh` exits 0
- `bash .claude/scripts/generate-context-line-counts.sh --check` reports no drift
- Diff read-through confirms every changed hunk is markdown prose in a context file with zero
  compile or elaboration surface, and that every cross-reference target named in the new text
  exists

---

### Phase 3: State explicit positions on both residual hypotheses [NOT STARTED]

**Goal**: Neither residual is left dangling. Each has a written verdict with a reason.

**Tasks**:
- [ ] Create `specs/decisions/settings-local-merge-content-loss-verdict.md` (this path is under
      `specs/**`, so task numbers ARE permitted here) capturing:
      - the verdict: 0/12 this round, 0/15 cumulative, named sample size, isolated-scratch-copy
        methodology, positive-control-validated detector;
      - the candidate root cause: the pre-`1692e33e8` restore-after-load ordering bug in
        `manager.regenerate`, whose failure shape matches the original observation exactly;
      - the writer constraint: `errors-append.sh update` cannot mutate `severity`, so the record
        was closed rather than downgraded, and why closure is the stronger outcome;
      - both positions below, with their reasoning.
- [ ] **Position on the concurrency residual: closed as out of scope. No follow-up task.**
      Reasoning to record: the fail-open `specs/.deploy-lock` mutex is a *deliberate, documented*
      design choice, not an untracked defect -- it mirrors the `specs/.commit-lock` shape and is
      described in both `deploy-headless.sh` and `batch-orchestration-guardrails.md`, which
      already warn that a concurrent redeploy "could corrupt the `.claude/` tree." The
      concurrency hypothesis is thus a *known and accepted* risk of an existing design, not a new
      finding, and it is a different defect class from "the merge loses content on a plain
      repeated wipe" -- which 0/15 rules out with reasonable confidence. Chasing a concurrency
      reproduction would be speculative work against an already-documented risk. The hypothesis is
      preserved in writing (Phase 2's known-limitation paragraph plus this record) so a future
      recurrence has a starting point: interleave two `--wipe` runs, or a `--wipe` against a
      concurrent settings edit, on the same target.
- [ ] **Position on `err_1786350581240_JyztWt` (ordering nondeterminism, low): stays open,
      unchanged, and does NOT fall out of this task.** Reasoning to record: it is real (present in
      all 12 pairs), correctly severity-rated as cosmetic to JSON consumers, and its only
      consequence is defeating a future byte-identical-diff acceptance criterion for deploy
      output. This task's Phase 2 removes the one place that criterion was *asserted as already
      met* -- which is the honest correction, not a fix. The actual fix (deterministic key/array
      ordering at generation time in the merge/index-build routine) is unchanged in scope and
      remains tracked under its own record's existing `suggested_action`. Do not mark it fixed.
- [ ] Confirm the working diff contains no edit under `lua/neotex/plugins/ai/shared/extensions/`
      and no edit to `agent-system/extensions/core/scripts/deploy-headless.sh`.

**Timing**: 0.75 hours

**Depends on**: 1, 2

**Verification Tier**: prose

**Files to modify**:
- `specs/decisions/settings-local-merge-content-loss-verdict.md` - new decision record

**Verification**:
- The decision record exists, is non-empty, and contains both a concurrency-residual verdict and
  an ordering-nondeterminism verdict, each with stated reasoning
- `jq -e '.errors[] | select(.id=="err_1786350581240_JyztWt") | .fix_status == "unfixed"' specs/errors.json`
  still passes (the position is "leave it open," and the verification proves it was left open)
- `git status --short` shows no modification under `lua/` and none to `deploy-headless.sh`

---

## Testing & Validation

- [ ] `jq empty specs/errors.json` parses clean and `err_1786350581208_23mAsn` reads
      `fix_status: "fixed"`, `fix_task: 1015`
- [ ] `err_1786350581240_JyztWt` remains `unfixed` (deliberate, per Phase 3's stated position)
- [ ] `bash .claude/scripts/check-task-references.sh` exits 0 -- no task-number citation reached
      any deliverable outside `specs/**`
- [ ] `bash .claude/scripts/generate-context-line-counts.sh --check` reports no drift
- [ ] No file under `lua/`, and no merge/backup/deploy script, appears in `git status --short`
- [ ] Every edit outside `specs/**` landed under `agent-system/extensions/**`, never `.claude/**`
      (`.claude/` is a disposable deploy artifact -- an edit there is silently wiped on the next
      regeneration)
- [ ] Full gate set for the repository runs before task completion, unchanged by the per-phase
      tiering above

## Artifacts & Outputs

- `specs/errors.json` - `err_1786350581208_23mAsn` closed via the sanctioned writer
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - corrected
  byte-identical claim + measured round-trip-fidelity subsection with known limitation
- `agent-system/extensions/core/index-entries.json` - `line_count` refresh, if drift
- `specs/decisions/settings-local-merge-content-loss-verdict.md` - new decision record
- `specs/1015_recheck_settings_local_merge_content_loss/summaries/01_close-out-merge-recheck-summary.md`

## Rollback/Contingency

Every change is additive documentation plus one field-scoped JSON mutation; nothing is
behavior-affecting, so rollback is low-risk.

- **Phase 1**: re-run the same sanctioned writer with `--fix-status unfixed` to reopen. Do not
  hand-edit `specs/errors.json` to roll back, for the same reason it must not be hand-edited to
  apply.
- **Phase 2**: `git revert` the commit, or restore the prior text of the two touched hunks. The
  original "byte-identically" wording is recoverable from git history.
- **Phase 3**: delete the decision record file.
- **If reproduction ever occurs after close-out**: reopen `err_1786350581208_23mAsn` via the
  writer, escalate through a new record if warranted, and start from the concurrency-interleaving
  procedure named in Phase 2's known-limitation paragraph -- that is the untested branch, and it
  is deliberately preserved rather than discarded.
