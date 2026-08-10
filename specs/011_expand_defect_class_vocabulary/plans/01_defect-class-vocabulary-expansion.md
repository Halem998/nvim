# Implementation Plan: Expand defect_class Vocabulary

- **Task**: 11 - expand_defect_class_vocabulary
- **Status**: [IMPLEMENTING]
- **Effort**: 1.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/011_expand_defect_class_vocabulary/reports/01_defect-class-vocabulary-gap.md
- **Artifacts**: plans/01_defect-class-vocabulary-expansion.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `defect_class` vocabulary is a closed ten-value enum with exactly two enumeration sites: the
`case` validator in `agent-system/extensions/core/scripts/system-defect-record.sh` and the Signal A
table in `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`. Three
concrete recorded defects — session/lock contention, a hook-regex path-depth boundary defect, and
deploy orphan-file drift — fit none of the ten existing classes. This plan adds exactly three new
values (`SESSION_LOCK_CONTENTION`, `HOOK_REGEX_BOUNDARY_DEFECT`, `DEPLOY_ORPHAN_DRIFT`) to both
sites, renames and removes nothing, and wires no detector. Done means: the script accepts the three
new values and still rejects unknown ones, the discrimination document defines them in its Signal A
table and records the extension decision, and every existing caller still validates unchanged.

### Research Integration

Key findings carried into this plan from the research report:

- **Exactly two enumeration sites**, both already in the task's declared `file_scope`. No JSON
  schema constrains `defect_class` (`events-schema.json` has no such property; `detail` is
  `additionalProperties: true` by design), so no schema edit is needed.
- **Fit analysis is settled**: each of the three instances was checked shape-by-shape against all
  ten existing classes and confirmed distinct. Specifically, `HOOK_REGEX_BOUNDARY_DEFECT` is the
  inverse of `HANDOFF_MISLOCATED` (a correctly-located write wrongly rejected by a buggy gate, not
  a wrongly-located write), and `DEPLOY_ORPHAN_DRIFT` is drift-over-time rather than the write-time
  violation `SOURCE_STORE_BOUNDARY_VIOLATION` names. The implementer does NOT need to redo this
  analysis — it is an input, not an open question.
- **No detector is wired by this task.** This follows the document's own precedent:
  `ARTIFACTS_MISSING_ON_SUCCESS` was added to the vocabulary with "not currently computed anywhere"
  before any detector existed. Naming the vocabulary and instrumenting a site are separate,
  sequential pieces of work.
- **Plan-marker drift is deliberately excluded** — the gap record names it as a fourth shape, but
  no concrete grounding error record exists for it and the task's WORK section scopes to three.
- **Consumer audit extended during planning**: the research grepped `defect_class` (underscore) and
  found four files. Planning re-ran the grep on the hyphenated flag `--defect-class`, which surfaces
  the full producer set: 17 call sites across 8 files (`skill-base.sh`, five `hooks/*.sh`,
  `skill-orchestrate/SKILL.md`, `skill-orchestrate-hard/SKILL.md`). Every one passes a single
  hardcoded literal; none contains a `case`/dispatch over the enum. This **confirms** rather than
  revises the research conclusion: no consumer needs a new arm.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Add exactly three new `defect_class` values to the validated enum in `system-defect-record.sh`,
  at every location within that file where the vocabulary or its count is stated.
- Define the same three values in the Signal A table of `system-defect-discrimination.md`, using
  the document's existing row format and its "not currently computed anywhere" convention.
- Record the extension as a deliberate decision in the document's existing
  "Extending the Signal A vocabulary is an explicit decision" section.
- Leave every existing class byte-identical, and leave every existing caller validating unchanged.

**Non-Goals**:
- Wiring any detector or `system-defect-record.sh` call site for the three new classes.
- Fixing the three underlying defects (the lock-acquire session-id mismatch, the 3-digit handoff
  regex, the additive-only deploy merge). This task names shapes; it does not repair sites.
- Adding a class for plan-marker drift (no concrete grounding instance).
- Reconciling the dedup rule's identity-key list, which already names only five of the ten existing
  instances. That staleness predates this task and is out of scope; flag it as a follow-up rather
  than folding it into this diff.
- Any edit under `.claude/**` — that tree is a disposable deploy artifact.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing the deployed `.claude/**` copy instead of the source store; the edit is silently wiped on next regenerate | H | M | Both target paths are absolute under `agent-system/extensions/core/`. Phase 3 greps `.claude/` for the new class names and expects zero hits until a deploy runs |
| A count word ("ten") left stale somewhere, so the doc and script disagree on vocabulary size | M | M | Phase 3 greps both files for `\bten\b`/`\bten-value\b` and asserts zero remaining references to the old count |
| Backslash-continued `case` pattern in the script broken by an inattentive edit, disabling validation entirely | H | L | Phase 1 runs `bash -n`; Phase 3 runs positive and negative round-trip invocations, so a validator that accepts everything fails the negative case |
| A future reader assumes the three new classes are detector-wired because they appear in the enum | M | M | Table rows use the existing **not currently computed anywhere** convention, matching `ARTIFACTS_MISSING_ON_SUCCESS` |
| Scope creep into fixing the underlying defects | M | L | Non-Goals state this explicitly; the file set is two files and Phase 3 asserts no other file changed |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch disjoint files and share
only the three class-name strings, which are fixed by this plan.

---

### Phase 1: Extend the validated enum in system-defect-record.sh [COMPLETED]

**Goal**: `system-defect-record.sh` accepts the three new classes, still rejects unknown values, and
states the new vocabulary size consistently everywhere it mentions it.

**Tasks**:
- [x] Read the whole file first and locate every occurrence of the vocabulary or its count; do not
      trust the line numbers below without re-confirming them (see Scope Hypothesis). *(completed:
      re-ran the grep — hits matched the hypothesized four locations exactly)*
- [x] Header comment (`--defect-class CLASS   One of the ten Signal A instances ...`): change the
      count word `ten` to `thirteen`. *(completed)*
- [x] `usage()` required-args block: append the three new values to the pipe-delimited list after
      `STATE_SYNC_DIVERGENCE`, preserving every existing entry and the existing line-continuation
      style. *(completed)*
- [x] `case "$defect_class" in` validation arm: add the three new literals to the same no-op `;;`
      arm, preserving every existing literal and the backslash line continuations exactly.
      *(completed)*
- [x] Comment above the `case` (`closed, ten-value enum`) and the invalid-value error message
      (`must be one of the ten Signal A instances`): update both count words to `thirteen`.
      *(completed)*
- [x] Run `bash -n` on the file. *(completed: exits 0)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts the vocabulary and its count appear at exactly four
locations in this one file — the header comment (~line 16), the `usage()` list (~lines 91-95), the
`case` arm (~lines 160-166), and the invalid-value error message (~line 165). Confirm at
implementation time by running `grep -n 'STATE_SYNC_DIVERGENCE\|\bten\b\|ten-value'` over the file
BEFORE editing and reconciling the hit list against these four; if a fifth location exists, edit it
too and note the discrepancy in the summary rather than silently skipping it.

**Files to modify**:
- `agent-system/extensions/core/scripts/system-defect-record.sh` - four count/enumeration locations
  extended by three values; no existing value altered.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/system-defect-record.sh` exits 0.
- `grep -c` for each of the three new class names returns at least 2 (usage list + `case` arm).
- `grep -n '\bten\b\|ten-value'` over the file returns no hits.
- A `git diff` read-through confirms no existing class literal was altered, reordered, or removed.

---

### Phase 2: Define the three classes in system-defect-discrimination.md [COMPLETED]

**Goal**: The canonical Signal A table defines all thirteen classes, and the extension-decision
section records this addition in the same style as the prior five-instance extension.

**Tasks**:
- [x] Read the Signal A table and the "Extending the Signal A vocabulary is an explicit decision,
      not a silent act" section in full before editing. *(completed)*
- [x] Append three rows to the Signal A table, after the `STATE_SYNC_DIVERGENCE` row, matching the
      existing two-column format (`Instance` = `` `CLASS` `` followed by an em-dash one-line
      definition; `Where it is already computed` = **not currently computed anywhere**, following
      the `ARTIFACTS_MISSING_ON_SUCCESS` row's convention verbatim): *(completed)*
  - [x] `SESSION_LOCK_CONTENTION` — a task-lock acquire/release call keyed to a session-id string
        that does not match the session-id used to register the same unit of work elsewhere (e.g.
        batch admission), so exact-match self-exclusion logic spuriously contends against the
        caller's own registration. *(completed)*
  - [x] `HOOK_REGEX_BOUNDARY_DEFECT` — a validation hook's regex or path-depth pattern encodes an
        unstated boundary assumption (e.g. a fixed digit-count quantifier) that silently breaks once
        real inputs cross that boundary, wrongly rejecting (or wrongly accepting) otherwise-valid
        inputs. *(completed)*
  - [x] `DEPLOY_ORPHAN_DRIFT` — a file or index entry present in the deployed tree with no
        corresponding source-store owner, surviving indefinitely because the deploy/merge routine is
        purely additive with no stale-entry pruning step. *(completed)*
- [x] Add a short paragraph to the extension-decision section, parallel in structure to the existing
      five-instance paragraph: name the three new instances, state they were added deliberately to
      name three concrete recorded defect shapes, and state that no existing instance was reworded
      or reinterpreted and no recorder was wired. *(completed)*
- [x] Describe the grounding defects by shape (lock/session self-contention, hook-regex path-depth
      boundary, deploy ghost index entries / undercounted orphan files) rather than by raw
      `err_...` identifier, matching this document's existing citation style, which names prior
      additions by class name only. *(completed)*
- [x] Re-grep the file for `\bten\b` and any other bare count word describing the vocabulary; update
      if present (see Scope Hypothesis). *(completed: only hit is "ten pre-existing instances" in
      the newly-added paragraph itself, an accurate count of unchanged prior rows, not a stale
      vocabulary-size total — left as-is)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: prose

**Scope Hypothesis**: This phase asserts the Signal A table currently has exactly 10 rows and that
the document states no bare count word for the vocabulary size outside the table (so no count-word
edit is needed beyond adding rows). Confirm at implementation time by counting table rows between
the header separator and the paragraph following the table, and by running
`grep -n '\bten\b\|\bTen\b\|ten instances'` over the file. If a count word IS present, update it to
`thirteen`; if the row count is not 10, stop and reconcile against the script's enum rather than
appending blindly.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` - three rows
  appended to the Signal A table; one paragraph added to the extension-decision section.

**Verification**:
- The Signal A table has 13 rows and each of the ten pre-existing rows is byte-identical in
  `git diff`.
- Each new row has both columns populated, with the "not currently computed anywhere" convention in
  column 2.
- The extension-decision section names all three new classes.
- No `err_...` identifier and no task number appears in the added prose (this file is a deliverable
  outside `specs/**`).
- Diff read-through confirms every changed hunk is markdown prose or a table row.

---

### Phase 3: Cross-file consistency and round-trip verification [NOT STARTED]

**Goal**: The script and the document agree on exactly thirteen classes, the new values validate end
to end, unknown values are still rejected, and no caller or deploy-tree file was touched.

**Tasks**:
- [ ] Extract the class list from the script's `case` arm and the class list from the document's
      Signal A table; diff the two sets and confirm they match exactly at thirteen values.
- [ ] Positive round trip: invoke the script once per new class with the minimum required arguments
      (`--defect-class`, `--detecting-site`, `--message`, and one Signal B argument) and confirm it
      does not exit 1 on enum validation.
- [ ] Negative round trip: invoke with a deliberately bogus class (e.g. `NOT_A_REAL_CLASS`) and
      confirm it still exits 1 with the invalid-class error — this proves the `case` arm was not
      accidentally flattened into an accept-all.
- [ ] Confirm the positive round trip's effect on `specs/events.jsonl`: if the invocations appended
      rows, either leave them (they are legitimate telemetry) or note them in the summary; do NOT
      hand-edit the events log to remove them.
- [ ] Re-run the producer audit: `grep -rn -- "--defect-class" agent-system/extensions` and confirm
      every call site still passes a literal that is in the thirteen-value enum, and that none
      contains a `case`/dispatch over the enum requiring a new arm (see Scope Hypothesis).
- [ ] Confirm `git status --short` shows exactly the two intended source-store files as modified
      (plus any `specs/**` artifacts), and that nothing under `.claude/**` was written.

**Timing**: 0.5 hours

**Depends on**: 1, 2

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the producer set is 17 `--defect-class` call sites across 8
files (`scripts/skill-base.sh`; `hooks/validate-state-sync.sh`, `validate-handoff-location.sh`,
`validate-plan-write.sh`, `validate-meta-write.sh`, `validate-no-task-references.sh`;
`skills/skill-orchestrate/SKILL.md`; `skills/skill-orchestrate-hard/SKILL.md`), all passing fixed
literals with no enum dispatch. Confirm at implementation time by re-running the grep and comparing
the hit count and file set; if a new call site has appeared, check whether it dispatches on the enum
before concluding no consumer change is needed.

**Files to modify**:
- None. This phase is verification only; any defect it finds is repaired in Phase 1 or Phase 2's
  file and re-verified.

**Verification**:
- Script-derived and document-derived class sets are identical, 13 values each.
- Three positive invocations pass enum validation; one bogus invocation exits 1.
- Producer audit shows no call site requiring change.
- `git status --short` shows no `.claude/**` modification.

---

## Testing & Validation

- [ ] `bash -n agent-system/extensions/core/scripts/system-defect-record.sh` exits 0.
- [ ] Each of `SESSION_LOCK_CONTENTION`, `HOOK_REGEX_BOUNDARY_DEFECT`, `DEPLOY_ORPHAN_DRIFT` is
      accepted by the script's enum validation.
- [ ] An unknown class value still exits 1 with the invalid-class message.
- [ ] All ten pre-existing class values are still accepted and byte-identical in both files.
- [ ] The Signal A table and the script `case` arm enumerate the same thirteen values.
- [ ] No count word `ten` describing the vocabulary remains in either file.
- [ ] No task-number citation appears in either modified file (both are deliverables outside
      `specs/**`).
- [ ] No file under `.claude/**` was created or modified.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/system-defect-record.sh` (modified)
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` (modified)
- `specs/011_expand_defect_class_vocabulary/summaries/01_defect-class-vocabulary-expansion-summary.md`
- Follow-up note (in the summary, not a code change): the dedup rule's identity-key list names only
  five of the now-thirteen instances — recommend a separate documentation-hygiene task.

## Rollback/Contingency

Both changes are purely additive to two files and touch no runtime logic beyond widening one
validation enum. To revert: `git checkout HEAD -- <the two source-store paths>` (safe only on a
clean tree; if uncommitted work exists elsewhere, snapshot first per the destructive-git rule). No
deploy step is triggered by this task, so no `.claude/**` state needs unwinding. If a defect is
found after the fact, the three new values can be removed from both files with no caller impact,
since no call site passes them.
