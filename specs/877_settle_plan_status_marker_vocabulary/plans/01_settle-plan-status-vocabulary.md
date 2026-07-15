# Implementation Plan: Settle the plan-level status marker vocabulary

- **Task**: 877 - Settle the plan-level status marker vocabulary (script vs spec)
- **Status**: [NOT STARTED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/877_settle_plan_status_marker_vocabulary/reports/01_settle-plan-status-vocabulary.md
- **Artifacts**: plans/01_settle-plan-status-vocabulary.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Resolve the documented vs. enforced divergence in the plan-level `- **Status**:` vocabulary by
adopting research resolution (b): extend the plan-format spec to the already-written verbs
`{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED, ABANDONED, COMPLETED}` (dropping the
never-implemented `IN PROGRESS`), widen `update-plan-status.sh`'s accept-set to match the full
documented set, and write down the intentional plan-level/phase-level marker asymmetry so it is no
longer implicit. Scope is limited to settling *what the vocabulary is*; wiring new call sites and
fixing fail-silent/plan-selection/phase-advance behavior are explicitly out of scope (dependent
hardening work). Definition of done: the script accept-set is a superset of the documented
plan-level set, no doc still lists `[IN PROGRESS]` at plan level, the phase-level docs are
unchanged in content but clarified as phase-scoped, and the asymmetry rationale is recorded.

### Research Integration

The plan implements the recommendation from
`reports/01_settle-plan-status-vocabulary.md` verbatim:
- Resolution (b) chosen over (a) for lexical alignment with the task-level vocabulary in
  `status-markers.md` (Findings 1-6, Decisions section).
- `IN PROGRESS` at plan level was never a real write target (zero live plan files carry it; the
  doc line predates the script), so removing it strands no data (Finding 5, Risk 1 mitigation).
- The plan-level/phase-level asymmetry (`ABANDONED` plan-only; `PARTIAL` at both levels but at
  different grain) is intentional and must be documented, not unified (report "Plan-level vs.
  phase-level asymmetry" section).
- The report corrected a path error carried in the task `file_scope`: the canonical markers file
  lives at `.claude/context/standards/status-markers.md`, not under `context/formats/`. This plan
  uses the verified `standards/` path.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found; no roadmap phases added.

## Goals & Non-Goals

**Goals**:
- Extend `plan-format.md`'s plan-level Status vocabulary to
  `{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED, ABANDONED, COMPLETED}`, removing `IN PROGRESS`.
- Widen `update-plan-status.sh`'s case statement (and its header-comment vocabulary list) to also
  accept `BLOCKED` and `ABANDONED`, so the accept-set is a superset of the documented set. Edit
  the existing script only.
- Document the intentional plan-level/phase-level marker asymmetry in the canonical spec and
  cross-reference it from the restating docs.
- Clarify in the two phase-level restating docs (`plan-format-enforcement.md`,
  `artifact-formats.md`) that their marker list is phase-heading-scoped and legitimately differs
  from the plan-level Status field vocabulary.

**Non-Goals**:
- No new scripts (constraint).
- Do NOT wire any new call site that invokes `update-plan-status.sh` with `BLOCKED`/`ABANDONED`
  (deferred to the dependent hardening task).
- Do NOT fix the fail-silent behavior, the `ls -t | head -1` plan-selection, or the
  phase-auto-advance logic (all deferred).
- Do NOT change the phase-level vocabulary itself (`update-phase-status.sh` and the phase marker
  lists stay functionally identical; only clarifying prose is added).
- No task-number references in any file outside `specs/**` (cite durable anchors only).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Widened `BLOCKED`/`ABANDONED` cases read as dead code (no caller) | L | M | Add a script comment stating they complete the documented plan-level vocabulary ahead of later hardening that adds call sites; cite `plan-format.md` as the durable anchor, never a task number |
| A reader re-opens the plan/phase asymmetry as a suspected bug | M | M | Transcribe the report's rationale into `plan-format.md` near Status Marker Requirements and cross-reference it from `status-markers.md` |
| Editing phase-level docs accidentally changes phase vocabulary | M | L | Phase-level marker *sets* stay byte-identical; only add clarifying "phase-heading-scoped" prose; verify via diff that no phase marker was added/removed |
| Task-number citation leaks into a `.claude/` deliverable | M | L | Use durable anchors (filenames, section names); Phase 4 greps changed files for `task [0-9]` patterns |
| Header comment in the script left stale after widening the case | L | M | Phase 1 updates the script header vocabulary line in the same edit as the case statement |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Widen update-plan-status.sh accept-set [COMPLETED]

**Goal**: Make the script accept the full documented plan-level vocabulary by adding `BLOCKED`
and `ABANDONED` to the case statement, keeping it an edit to the existing script (no new script).

**Tasks**:
- [x] In the normalize `case "$new_status" in` block (lines 21-27), add two branches:
      `BLOCKED|blocked) new_status="BLOCKED" ;;` and
      `ABANDONED|abandoned) new_status="ABANDONED" ;;`, placed before the `*)` catch-all, keeping
      the existing four branches intact. *(completed)*
- [x] Update the header-comment vocabulary line (line 5,
      `# STATUS values: IMPLEMENTING, COMPLETED, PARTIAL, NOT_STARTED`) to also list `BLOCKED` and
      `ABANDONED`, so the doc-comment matches the case statement. *(completed)*
- [x] Add a one-line explanatory comment above/inside the case block noting that `BLOCKED` and
      `ABANDONED` complete the documented plan-level vocabulary (see `plan-format.md`) ahead of
      later hardening that wires call sites. Do NOT reference any task number. *(completed)*
- [x] Leave all other logic untouched (plan-file selection, idempotency check, `sed` update,
      verification block). *(completed: verified unchanged)*

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/scripts/update-plan-status.sh` - widen case statement (lines 21-27), update header
  comment (line 5), add explanatory comment.

**Verification**:
- `bash -n .claude/scripts/update-plan-status.sh` parses cleanly.
- Manual case trace: `BLOCKED`, `blocked`, `ABANDONED`, `abandoned` each normalize to the
  uppercase canonical; an unknown value still hits `*)` and exits 1.
- `grep -n 'BLOCKED\|ABANDONED' .claude/scripts/update-plan-status.sh` shows both new branches and
  the updated header comment.

---

### Phase 2: Extend plan-format.md plan-level vocabulary and document the asymmetry [COMPLETED]

**Goal**: Replace the plan-level Status vocabulary on line 6 with the resolution-(b) set and add a
callout, near the Status Marker Requirements section, explaining the intentional plan-level vs.
phase-level marker asymmetry.

**Tasks**:
- [x] Edit line 6: change the marker list from
      `` `[NOT STARTED]`, `[IN PROGRESS]`, `[BLOCKED]`, `[ABANDONED]`, `[COMPLETED]` `` to
      `` `[NOT STARTED]`, `[IMPLEMENTING]`, `[PARTIAL]`, `[BLOCKED]`, `[ABANDONED]`, `[COMPLETED]` ``,
      keeping the trailing `per status-markers.md` reference. *(completed)*
- [x] Add a short callout adjacent to the `## Status Marker Requirements` section (around line
      129) titled to the effect of "Plan-level vs. phase-level markers" that states: (a) plan-level
      Status uses the six markers above (a subset of the task-level vocabulary in
      `status-markers.md`); (b) `ABANDONED` is deliberately plan/task-level only — no code path
      abandons a single phase while leaving siblings active, so phase headings have no `ABANDONED`;
      (c) plan-level `PARTIAL` is an aggregate "this document is stalled/resumable" signal, distinct
      from and compatible with any individual phase heading carrying its own `[PARTIAL]`.
      *(completed: added "### Plan-level vs. phase-level markers" subsection)*
- [x] Cite durable anchors only (`status-markers.md`, `update-phase-status.sh`,
      section names); no task numbers. *(completed: verified via grep)*

**Timing**: 35 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/formats/plan-format.md` - line 6 vocabulary; new asymmetry callout near
  Status Marker Requirements (line 129).

**Verification**:
- `grep -n 'IN PROGRESS' .claude/context/formats/plan-format.md` returns no plan-level Status-field
  hit (phase-heading example lines, if any, are unaffected).
- Line 6 lists exactly the six resolution-(b) markers.
- The callout is present and names both the `ABANDONED`-plan-only and `PARTIAL`-grain rationale.
- No `task [0-9]` reference introduced.

---

### Phase 3: Propagate rationale to restating docs [COMPLETED]

**Goal**: Keep the three restating docs consistent with the settled vocabulary: add the asymmetry
cross-reference to `status-markers.md`, and clarify in the two phase-level docs that their marker
list is phase-heading-scoped (functionally unchanged).

**Tasks**:
- [x] `status-markers.md`: add a brief note (natural home: near the `[PARTIAL]`/`[ABANDONED]`
      definitions or in a short "Plan-level vs. phase-level" subsection) stating that the plan-level
      Status field uses the subset `{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED, ABANDONED,
      COMPLETED}` and cross-referencing the fuller rationale callout in `plan-format.md`. Use the
      verified path `.claude/context/standards/status-markers.md`. *(completed)*
- [x] `plan-format-enforcement.md` (line 13): clarify that the listed markers
      (`[NOT STARTED]`, `[IN PROGRESS]`, `[COMPLETED]`, `[PARTIAL]`, `[BLOCKED]`) are the
      **phase-heading** vocabulary, distinct from the plan-level Status field vocabulary documented
      in `plan-format.md`. Do NOT change the phase marker set itself. *(completed)*
- [x] `artifact-formats.md` (Phase Status Markers, lines 83-90): retitle/annotate the section so it
      is explicit these are phase-heading markers used inside plan files, distinct from the
      plan-level Status field. Do NOT change the phase marker set itself. *(completed)*
- [x] All cross-references use durable anchors (filenames, section names); no task numbers.
      *(completed: verified via grep)*

**Timing**: 40 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/context/standards/status-markers.md` - plan-level subset note + cross-reference.
- `.claude/rules/plan-format-enforcement.md` - clarify line 13 markers are phase-heading-scoped.
- `.claude/rules/artifact-formats.md` - clarify Phase Status Markers section is phase-scoped.

**Verification**:
- Phase marker *sets* in `plan-format-enforcement.md` and `artifact-formats.md` are unchanged
  (diff shows only added clarifying prose, no marker added or removed).
- `status-markers.md` references the plan-level subset and points to `plan-format.md`.
- No `task [0-9]` reference introduced in any of the three files.

---

### Phase 4: Cross-file consistency verification [NOT STARTED]

**Goal**: Confirm the settled vocabulary is internally consistent across script and docs and that
deliverable rules are honored.

**Tasks**:
- [ ] Confirm the script accept-set is a superset of the documented plan-level set: extract the
      case-statement canonical values from `update-plan-status.sh` and the six markers from
      `plan-format.md:6`; every documented marker must be accepted by the script.
- [ ] Confirm no doc lists `[IN PROGRESS]` as a plan-level Status value
      (`grep -rn 'IN PROGRESS' .claude/context/formats/plan-format.md
      .claude/context/standards/status-markers.md` — remaining hits, if any, must be phase-level).
- [ ] Confirm the phase-level vocabulary is unchanged in `update-phase-status.sh`,
      `plan-format-enforcement.md`, and `artifact-formats.md` (no marker added/removed).
- [ ] Run the no-task-references check over all five changed files:
      `grep -rniE 'task[ -][0-9]+' <changed files>` returns nothing (durable anchors only).
- [ ] `bash -n .claude/scripts/update-plan-status.sh` still parses.

**Timing**: 25 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- None (verification only).

**Verification**:
- Superset check passes: `{NOT STARTED, IMPLEMENTING, PARTIAL, BLOCKED, ABANDONED, COMPLETED}` all
  accepted by the script.
- Zero plan-level `[IN PROGRESS]` occurrences remain.
- Zero task-number citations across the five changed files.

## Testing & Validation

- [ ] `bash -n .claude/scripts/update-plan-status.sh` parses cleanly after the case-statement edit.
- [ ] Script accepts `BLOCKED`, `blocked`, `ABANDONED`, `abandoned` (normalize to uppercase) and
      still rejects an unknown value via the `*)` branch (exit 1).
- [ ] `plan-format.md:6` lists exactly the six resolution-(b) markers; `[IN PROGRESS]` removed.
- [ ] Script accept-set is a superset of the documented plan-level set.
- [ ] Phase-level marker sets unchanged across `update-phase-status.sh`,
      `plan-format-enforcement.md`, `artifact-formats.md`.
- [ ] Asymmetry rationale present in `plan-format.md` and cross-referenced from `status-markers.md`.
- [ ] No task-number references in any of the five changed files (all under `.claude/`).

## Artifacts & Outputs

- `.claude/scripts/update-plan-status.sh` (widened accept-set + header/comment)
- `.claude/context/formats/plan-format.md` (extended vocabulary + asymmetry callout)
- `.claude/context/standards/status-markers.md` (plan-level subset note + cross-reference)
- `.claude/rules/plan-format-enforcement.md` (phase-scope clarification)
- `.claude/rules/artifact-formats.md` (phase-scope clarification)
- `specs/877_settle_plan_status_marker_vocabulary/summaries/01_settle-plan-status-vocabulary-summary.md`
  (on completion)

## Rollback/Contingency

All changes are localized edits to one script and four Markdown files with no runtime call-site
changes, so reversion is low-risk. If any edit misbehaves: `git checkout -- <file>` the specific
file (or `git revert` the phase commit) to restore the prior state. The script change is additive
(new case branches only); reverting it simply narrows the accept-set back to the original four
values without affecting existing callers. The doc changes are prose-only and independently
revertible per file.
