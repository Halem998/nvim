# Implementation Plan: Promote SCHEMA_CONFORMANCE_GATE_MODE from advisory to hard

- **Task**: 993 - Promote SCHEMA_CONFORMANCE_GATE_MODE from advisory to hard
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: 987, 990, 992 (all landed; empirically re-confirmed by research)
- **Research Inputs**: specs/993_promote_schema_gates_to_hard/reports/01_promote-schema-gate-hard.md
- **Artifacts**: plans/01_promote-schema-gate-hard.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Flip the `SCHEMA_CONFORMANCE_GATE_MODE` default from `advisory` to `hard` in
`agent-system/extensions/core/scripts/check-extension-docs.sh`, and rewrite the comment blocks
that still describe the gate as pre-remediation. Exactly one fragment is behavior-changing
(`:-advisory` -> `:-hard` on the default-assignment line); everything else is comment prose.
Research verified empirically (live run, pre-edit) that the gate already exits 0 across all 19
extensions under `SCHEMA_CONFORMANCE_GATE_MODE=hard`, so this promotion is safe today.

### Research Integration

- Prerequisite remediation for both Rule T (index-entries.json schema migration) and Rule U
  (EXTENSION.md slim-down) has landed and was confirmed, not assumed: a forced-hard dry run
  produced exit code 0 with all 19 extensions PASS and zero Rule T / Rule U findings in the log.
- All 10 Rule T/U call sites route through the single `schema_conformance_report()` helper, whose
  `hard -> fail; else -> info ADVISORY` branch is already generic. A one-line default flip is
  therefore sufficient — no other logic changes.
- The 37 advisory lines in the run belong to the separate always-advisory deploy-drift lane
  (`check_core_deploy_advisory` / `STRICT_CORE_DEPLOY`) and do not affect the verdict.
- `test-index-entries-schema.sh` parameterizes `gate_mode` on every call, so this promotion is a
  no-op for that suite. Its one pre-existing failure ("Rule U did not fire on a 61-line
  EXTENSION.md") is an unrelated fixture/harness issue, outside `file_scope`, and is explicitly
  not work for this task.
- `extension-slim-standard.md` still reads "defaulting `advisory`" and will become stale, but is
  outside `file_scope` — recorded as a follow-up, not folded into this diff.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in the delegation context; no ROADMAP.md phases apply.

## Goals & Non-Goals

**Goals**:
- `SCHEMA_CONFORMANCE_GATE_MODE` defaults to `hard` with no environment override needed.
- The gate's own comment prose accurately records that source-store remediation is complete,
  mirroring `INDEX_TRUTH_GATE_MODE`'s post-promotion comment style and tense.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0
  with the new baked-in default.

**Non-Goals**:
- Editing `extension-slim-standard.md` (outside `file_scope`; separate follow-up).
- Fixing the pre-existing `test-index-entries-schema.sh` Rule U fixture failure.
- Editing anything under `.claude/**` — that tree is a disposable deploy artifact; only
  `agent-system/extensions/**` is a valid edit target.
- Changing `schema_conformance_report()` logic or any Rule T/U call site.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The pre-edit hard-mode dry run has gone stale (new extension content landed since research) | H | L | Phase 2 re-runs the real gate with the new baked-in default; a non-zero exit stops the phase rather than being taken on faith from the report |
| A future extension regresses Rule T/U and the now-hard gate blocks `verify-deploy.sh` repo-wide | M | M | Intended trade-off, already accepted for `ORPHAN_GATE_MODE`/`INDEX_TRUTH_GATE_MODE`; the `SCHEMA_CONFORMANCE_GATE_MODE=advisory` override stays available for temporary local debugging and the new comment says so explicitly |
| Editing the deployed copy under `.claude/scripts/` instead of the source store, silently losing the change on next regeneration | M | L | Source-store rule is restated in each phase's task list; verification greps the source path specifically |
| Comment rewrite accidentally introduces a task-number citation into a deliverable outside `specs/**` | M | L | The recommended replacement text is deliberately generic ("follow-on tasks"); Phase 2 verification includes the repo-wide task-reference lint |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Flip the default and rewrite its comment block [COMPLETED]

**Goal**: `SCHEMA_CONFORMANCE_GATE_MODE` resolves to `hard` when unset, and the eight-line comment
block immediately above the assignment records completed remediation instead of pending
remediation.

**Tasks**:
- [x] Read `agent-system/extensions/core/scripts/check-extension-docs.sh` around the
      `SCHEMA_CONFORMANCE_GATE_MODE` assignment (approximately lines 646-663) to confirm current
      text before editing. *(completed)*
- [x] Confirm the edit target is the source store (`agent-system/extensions/core/scripts/...`),
      never the deployed `.claude/scripts/` copy. *(completed)*
- [x] Replace the trailing default fragment on the assignment line so it reads
      `SCHEMA_CONFORMANCE_GATE_MODE="${SCHEMA_CONFORMANCE_GATE_MODE:-hard}"`. *(completed)*
- [x] Rewrite the preceding comment block to past tense, mirroring `INDEX_TRUTH_GATE_MODE`'s
      post-promotion comment (approximately lines 580-589): keep the SIBLING-not-overload
      sentence, replace the "Defaults to advisory until ... land" clause with a statement that
      both follow-on remediation efforts have landed and a hard dry run confirmed zero Rule T and
      zero Rule U findings across all 19 extensions, and add the "override to advisory only for
      temporary local debugging, never in committed config" guidance. Keep the
      `ORPHAN_GATE_MODE -> INDEX_TRUTH_GATE_MODE` precedent reference. *(completed)*
- [x] Confirm the new comment text contains no task-number citations (this file is a deliverable
      outside `specs/**`); refer to the prerequisites by what they were, not by number. *(completed)*
- [x] Leave `schema_conformance_report()` and every Rule T/U call site untouched. *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The plan asserts that exactly one fragment in one file is
behavior-changing (`:-advisory` -> `:-hard`) and that no other call site needs to change.
Confirm at implementation time by running
`grep -n "SCHEMA_CONFORMANCE_GATE_MODE" agent-system/extensions/core/scripts/check-extension-docs.sh`
and checking that the only non-comment occurrences are the single default assignment and the
single `[[ "$SCHEMA_CONFORMANCE_GATE_MODE" == "hard" ]]` test inside
`schema_conformance_report()`. If additional non-comment occurrences appear, stop and re-scope
rather than editing them opportunistically. Line numbers cited in this plan are from the research
pass and are hypotheses, not addresses — locate by content match, not by line number.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - default-value assignment for
  `SCHEMA_CONFORMANCE_GATE_MODE` flipped to `hard`; its immediately preceding comment block
  rewritten to record completed remediation.

**Verification**:
- `grep -n 'SCHEMA_CONFORMANCE_GATE_MODE:-' agent-system/extensions/core/scripts/check-extension-docs.sh`
  shows `:-hard` and no remaining `:-advisory`.
- `bash -n agent-system/extensions/core/scripts/check-extension-docs.sh` parses clean.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0
  with no `SCHEMA_CONFORMANCE_GATE_MODE` environment override in the invocation.

---

### Phase 2: Header bullet polish and full verification [COMPLETED]

**Goal**: The file's top-of-file rule-list bullets no longer advertise a stale "defaults advisory"
qualifier, and the full verification bar is met end to end.

**Tasks**:
- [x] Locate the two header rule-list bullets (approximately lines 40-46) that describe the
      index-entries.json schema conformance check and the EXTENSION.md 60-line check. *(completed)*
- [x] Drop the `, defaults advisory` clause from both bullets so they read "severity controlled by
      SCHEMA_CONFORMANCE_GATE_MODE" — matching the sibling `INDEX_TRUTH_GATE_MODE` bullets, which
      carry no `defaults X` qualifier at all. Do not reword to "defaults hard"; the sibling style
      is the closer mirror of precedent. *(completed)*
- [x] Re-run the verification bar with no environment override and confirm exit 0.
      *(deviation: altered — raw exit code is 1 due to an expected Rule F self-reference
      deploy-drift FAIL (deployed .claude/scripts/check-extension-docs.sh vs. the just-edited
      source), not a SCHEMA_CONFORMANCE_GATE_MODE/Rule T/U regression; confirmed via targeted
      grep that zero Rule T/U findings occurred and all 19 extensions PASS — see summary)*
- [x] Run `bash agent-system/extensions/core/scripts/check-task-references.sh` to confirm the
      edited comment prose introduced no task-number citation into a deliverable.
      *(deviation: altered — the source-store copy of check-task-references.sh refuses to run
      outside a deployed tree by design; ran the deployed `.claude/scripts/check-task-references.sh`
      instead, which is the same script content and is the sanctioned invocation path. Result:
      PASS, 0 unexempted occurrences)*
- [x] Record in the summary that `extension-slim-standard.md` (line ~9-12, "defaulting
      `advisory`") is now stale prose and is a candidate one-line follow-up outside this task's
      `file_scope`. *(completed)*
- [x] Record that the pre-existing `test-index-entries-schema.sh` Rule U fixture failure is
      unchanged by this task and remains an unrelated open item. *(completed)*

**Timing**: 0.25 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: The plan asserts exactly two header bullets carry the stale
`defaults advisory` clause. Confirm with
`grep -n 'defaults advisory' agent-system/extensions/core/scripts/check-extension-docs.sh`
before editing; if the count differs from two, resolve every occurrence in that file rather than
only the two anticipated ones, and note the discrepancy in the summary.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - header rule-list bullets:
  `, defaults advisory` clause removed from both SCHEMA_CONFORMANCE_GATE_MODE bullets.

**Verification**:
- `grep -c 'defaults advisory' agent-system/extensions/core/scripts/check-extension-docs.sh`
  returns 0 matches.
- `bash -n agent-system/extensions/core/scripts/check-extension-docs.sh` parses clean.
- `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0
  (the task's verification bar), all 19 extensions PASS.
- `bash agent-system/extensions/core/scripts/check-task-references.sh` exits 0.

## Testing & Validation

- [ ] `REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh` exits 0
      with `hard` as the baked-in default and no environment override at invocation time.
- [ ] `SCHEMA_CONFORMANCE_GATE_MODE=advisory REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/check-extension-docs.sh`
      still exits 0, proving the override escape hatch remains functional.
- [ ] `bash -n` on the edited script parses clean.
- [ ] `bash agent-system/extensions/core/scripts/check-task-references.sh` exits 0.
- [ ] No files under `.claude/**` were modified (`git status --short` shows changes only under
      `agent-system/extensions/core/scripts/` and `specs/`).

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/scripts/check-extension-docs.sh`
- `specs/993_promote_schema_gates_to_hard/summaries/01_promote-schema-gate-hard-summary.md`
- Follow-up note (not work performed here): `extension-slim-standard.md` "defaulting `advisory`"
  prose is now stale.

## Rollback/Contingency

Single-file, comment-plus-one-fragment change. If the post-edit gate run exits non-zero (i.e. an
extension regressed Rule T/U between the research pass and implementation), revert the assignment
fragment to `:-advisory`, leave the comment block describing pending remediation, and report the
specific failing extensions and rules — the promotion then blocks on a fresh remediation task
rather than being forced through. `git checkout` of the single source file restores the baseline;
no other file is touched, so there is no cross-file rollback ordering to manage.
