# Implementation Plan: Task #973

- **Task**: 973 - Make reconcile-task-status.sh recover from a malformed handoff status instead of refusing promotion
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/973_recover_reconcile_from_malformed_handoff_status/reports/01_malformed-handoff-recovery-design.md
- **Artifacts**: plans/01_malformed-handoff-recovery.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`handoff_permits_promotion()` in `agent-system/extensions/core/scripts/reconcile-task-status.sh`
permits promotion when `.orchestrator-handoff.json` is absent but refuses when the file is present
with a `status` outside the six-value normative enum — treating a value that makes no interpretable
claim as *more* suspicious than no claim at all, which wedges the task because
`record_refused_promotion()` writes no state for such values and every re-run hits the identical
guard. This plan replaces the bare `==` fallthrough with an explicit three-way split (match →
permit; on-enum terminal mismatch → refuse, unchanged; no-terminal-claim → permit with a loud,
mandatory diagnostic), consolidates the one un-refactored call site in the `partial` branch onto
the same helper, and adds a fixture-driven regression suite that asserts the parity bar the task
sets: the off-vocabulary case must be at least as permissive as the same directory with the handoff
file deleted. Definition of done: the suite passes, and the rationale (including the rejected
alternatives) is recorded in the script so a future reader does not re-tighten it by reflex.

### Research Integration

The research report's core design is adopted: off-vocabulary status is treated as equivalent to a
missing handoff (permit, deferring to the same artifact-on-disk evidence the missing-handoff branch
already relies on), with a mandatory diagnostic naming both the offending value and the legal set.
Both rejected alternatives are adopted as rejections and must be recorded in the script comment: a
refuse-with-diagnostic-only route (preserves the wedge, only adds visibility) and a known-bad
synonym table (unmaintainable, launders malformed writes, risks false-positive promotion). The
report's identification of the `partial` branch (lines 433-442) as the sole un-consolidated
`.status` reader is adopted as Phase 2, and its finding that `orchestrate-recover-outcome.sh` is a
different mechanism at a different call site is adopted as a Non-Goal.

**One refinement the report does not cover, discovered while aligning with the sibling
discrimination contract.** The report's proposed `case` recognizes exactly the six enum values and
routes *everything else* — including `in_progress` — down the "off-vocabulary" branch with a
diagnostic calling the value off-schema. That wording would contradict
`context/patterns/system-defect-discrimination.md`, whose `OFF_SCHEMA_STATUS` row states verbatim
that `in_progress` "is a valid non-terminal marker, not a violation", and
`docs/architecture/handoff-schema.md:372` likewise lists `in_progress` alongside
missing/stale/unparseable as a recognized non-success condition rather than a schema breach. The
correct decision (see Decisions below) keeps `in_progress` in the **permit** bucket — it makes no
terminal claim, exactly like a missing handoff — but gives it **distinct diagnostic wording** so
the script never labels a recognized non-terminal marker as malformed. This is the only substantive
departure from the report's proposed code block, and it exists specifically to keep this fix from
inventing a second, competing notion of "malformed status".

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context; no ROADMAP.md was consulted.

## Goals & Non-Goals

**Goals**:
- Give the off-enum-status case a defined behavior that is exactly as permissive as the
  missing-handoff case the same function already permits (identical code path, not merely
  equivalent in spirit).
- Preserve today's refusal for every on-enum terminal value that is not this phase's expected
  success value (`blocked`, `partial`, `failed`, another phase's success value).
- Make the recovery non-silent in every branch: a mandatory `stderr` diagnostic naming the
  offending value and the full six-value legal set for the off-vocabulary case, and separate
  wording for the recognized-non-terminal (`in_progress`) case.
- Apply the semantics at every call site, including the `partial` branch's inline duplicate, so the
  behavior is not fixed at five of six readers.
- Record the rationale and the two rejected alternatives in the script itself.
- Leave a fixture-driven regression suite behind that mechanically asserts the parity bar.

**Non-Goals**:
- Do not touch `context/patterns/system-defect-discrimination.md` — that file belongs to a sibling
  task in this batch and this task must stay file-disjoint from it. Align *with* its contract by
  reading it; do not edit it.
- Do not route this fix through `orchestrate-recover-outcome.sh`, and do not modify that script.
  It is a narrower `.return-meta.json` reader for the handoff-missing/stale case at a different
  call site, with its own documented policy against permissive off-schema fallbacks.
- Do not redo the agent-contract half of the underlying incident (whether research agents may write
  handoffs at all; a Stage 7 final-metadata contract; artifacts array-of-objects propagation).
  Three separate tasks already own that work.
- Do not add a synonym-normalization table for known-bad status values, now or as a follow-up.
- Do not widen the accepted enum to include values from the adjacent-but-distinct `state.json`
  task-status or wezterm notification vocabularies (`completed` in particular).
- Do not edit `docs/architecture/handoff-schema.md` or any other standards document; the research
  found no documentation gap, only a script-behavior gap.
- Do not write to `.claude/**`. It is a gitignored, disposable deploy artifact.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Permitting a garbled status promotes a task whose agent actually failed | M | L | The identical risk is already accepted for the missing-handoff case (a crashed agent that wrote nothing is already permitted on artifact evidence alone). Every branch reaching this guard has already found the phase's success artifact on disk, so this case is strictly better-evidenced than the missing-handoff case it mirrors. No new risk class is introduced. |
| A future reader "simplifies" the permissive branch back to strict refusal, restoring the wedge | H | M | Phase 1 writes an explicit do-not-re-tighten comment naming both rejected alternatives; Phase 3 leaves a regression test that fails loudly if the behavior is reverted. |
| The `in_progress` diagnostic drifts into calling a recognized non-terminal marker a schema violation, contradicting the sibling discrimination contract | M | M | Separate diagnostic wording is a hard requirement of Phase 1, asserted by a dedicated test case in Phase 3 that greps the emitted text. |
| Consolidating the `partial` branch changes its behavior for on-enum non-`implemented` values (silent no-op today, logged refusal + `record_refused_promotion` after) | L | H (intended) | Deliberate and called out, not a late-discovered side effect. `record_refused_promotion` writes state only for `blocked`/`partial`, and writing `partial` on an already-`partial` task is an idempotent no-op transition. |
| Verification cannot run the script from the source store: `deploy-root-guard.sh` hard-fails outside a `.claude/`- or `.opencode/`-parented `scripts/` tree | M | H (certain) | Phase 3's harness builds a throwaway sandbox deploy tree (`$TMP/.claude/scripts/` + `$TMP/specs/state.json`) and drives `--dry-run` invocations there. Never copy the modified script into the repo's real `.claude/` tree to test it. |
| `set -e` interaction: a failing `jq` inside the new `case` scaffolding aborts the script instead of falling through | M | L | The helper is only ever invoked in an `if !` condition, where `set -e` is suppressed; keep it that way and keep the `2>/dev/null` + `// ""` guards. Phase 3 includes an unparseable-JSON fixture that would catch a regression here. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is a deliberate linear chain: the
`partial` consolidation must target the already-rewritten helper, and the test suite asserts the
final semantics of both.

### Phase 1: Rewrite `handoff_permits_promotion()` with the three-way split [NOT STARTED]

**Goal**: Replace the bare `[[ "$handoff_status" == "$expected_status" ]]` fallthrough with an
explicit three-way classification, and record the rationale plus both rejected alternatives in the
script.

**Tasks**:
- [ ] Read `agent-system/extensions/core/scripts/reconcile-task-status.sh` lines 181-203 and confirm
      the current helper text matches the report's verbatim quote before editing.
- [ ] Rewrite the body so that, after the existing missing-file early return and the `jq` read:
      (a) `status == expected_status` returns 0, unchanged; (b) a `case` arm matching exactly
      `researched|planned|implemented|partial|failed|blocked` returns 1 — genuine terminal negative
      evidence, refusing exactly as today; (c) an arm matching `in_progress` returns 0 after
      emitting a diagnostic that names it as a **recognized non-terminal marker carrying no
      terminal claim**, explicitly NOT as an off-schema or malformed value; (d) the `*` default
      returns 0 after emitting a diagnostic naming the offending value verbatim AND the full
      six-value legal set, and stating that the handoff is being treated as if absent.
- [ ] Route both diagnostics to `stderr` with the existing `[reconcile] WARNING:` prefix used
      elsewhere in this file, and include the task number.
- [ ] Ensure the empty-string case (handoff present but `.status` absent, or the file unparseable so
      `jq` yields nothing) lands in the `*` default and therefore permits. Word that diagnostic so
      an empty value is legible rather than rendering as a bare `''` with no explanation.
- [ ] Update the helper's docstring (lines 181-185) to describe the three-way contract instead of
      the current "otherwise refuse" sentence, and cite the `artifact_newer_than_last_update`
      docstring's already-named "signal absent -> permit" philosophy as the governing principle.
- [ ] Add the do-not-re-tighten note naming both rejected alternatives (refuse-with-diagnostic-only;
      known-bad synonym table) and why each was rejected.
- [ ] Add a short note to the file's top-of-file header block recording that an off-enum handoff
      status is treated as equivalent to a missing handoff, so a reader skimming the header sees the
      contract without reading the helper.
- [ ] Leave `handoff_status_value()` unchanged — it already returns the raw string, and the
      malformed case no longer reaches the callers' refusal lines.

**Timing**: 45 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: the research report asserts five call sites use this helper directly
(~326, ~358, ~390, ~475, ~511) and that all five call `handoff_status_value()` +
`record_refused_promotion()` on refusal. Confirm at implementation time with
`grep -n 'handoff_permits_promotion' agent-system/extensions/core/scripts/reconcile-task-status.sh`
and check that each hit's refusal block still reads correctly given that malformed values no longer
reach it. If the count differs from five, reconcile before proceeding rather than assuming the
report.

**Files to modify**:
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — rewrite
  `handoff_permits_promotion()` (lines ~181-195), extend its docstring, add the header-block note.

**Verification**:
- `bash -n agent-system/extensions/core/scripts/reconcile-task-status.sh` parses cleanly.
- `shellcheck` on the file reports no new findings relative to its pre-edit baseline (capture the
  baseline first; pre-existing findings are not this phase's scope).
- Diff read-through confirms the six-value arm is byte-exact against the enum in
  `context/formats/return-metadata-file.md` — no extra values, no `completed`.
- The two diagnostics are textually distinct, and only the `*`-default one uses off-schema /
  malformed framing.

---

### Phase 2: Consolidate the `partial` branch onto the shared helper [NOT STARTED]

**Goal**: Remove the inline duplicate handoff-status check in the `partial` branch so the new
semantics apply at every reader, not five of six.

**Tasks**:
- [ ] Replace the inline block (`handoff_file=...` / `[[ -f ]]` / `jq` / `!= "implemented"` →
      `exit 0`, lines ~433-442) with `if ! handoff_permits_promotion "implemented"; then ... fi`.
- [ ] Inside the refusal branch, follow the same triad the other five sites already use:
      `handoff_status=$(handoff_status_value)`, a `[reconcile] Task N: status=partial, ... handoff
      status=$handoff_status — refusing promotion` line, `record_refused_promotion
      "$handoff_status"`, then `exit 0`.
- [ ] Emit the refusal line unconditionally (not only under `--dry-run`, which is the current
      under-instrumented behavior), matching the other five sites.
- [ ] Confirm no other reader of `.orchestrator-handoff.json`'s `.status` remains in the file.
- [ ] Add a one-line comment noting the intended behavior change for on-enum non-`implemented`
      values (previously a silent no-op, now a logged refusal plus an idempotent
      `record_refused_promotion` call) so the diff's intent is legible.

**Timing**: 30 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: the report asserts the `partial` branch is the ONLY remaining site reading
`.status` directly. Confirm with
`grep -n "orchestrator-handoff\|\.status\|handoff_status=" agent-system/extensions/core/scripts/reconcile-task-status.sh`
and enumerate every hit before editing. If a second inline reader exists, consolidate it too and
record the discovery in the summary rather than silently leaving it.

**Files to modify**:
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — `partial` branch (lines
  ~421-463).

**Verification**:
- `bash -n` parses cleanly; `shellcheck` shows no new findings.
- `grep -c 'jq -r .\.status' ` on the file drops by one relative to the pre-edit count, and the
  only remaining occurrence is inside `handoff_permits_promotion` / `handoff_status_value`.
- The refusal-branch shape is diff-identical in structure to the `implementing` branch's refusal
  block.

---

### Phase 3: Add the fixture-driven regression suite [NOT STARTED]

**Goal**: Leave a mechanical regression guard that asserts the chosen semantics, including the
task's explicit parity bar (off-vocabulary at least as permissive as handoff-deleted).

**Tasks**:
- [ ] Create `agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh`,
      modelled structurally on `scripts/tests/test-phase-heading-patterns.sh`
      (`pass()`/`fail()`/`info()` helpers, `PASSED`/`FAILED` counters, `mktemp -d` + `trap cleanup
      EXIT`, exit 0 all-pass / 1 any-fail / 2 environment error).
- [ ] Implement a sandbox-deploy harness: `mktemp -d`, create `$SANDBOX/.claude/scripts/`, copy the
      resolved `scripts/` tree into it (deploy-tree-first then source-store-fallback candidate
      list, same idiom as the model test), and write a minimal
      `$SANDBOX/specs/state.json` containing one synthetic task with a `project_name`, a `status`,
      and a `last_updated`. This is what satisfies `deploy-root-guard.sh`.
- [ ] Drive every case as `bash "$SANDBOX/.claude/scripts/reconcile-task-status.sh" <num> <sess>
      --dry-run`, capturing stdout and stderr separately, and asserting on the emitted text
      (`Would promote` vs `refusing promotion`) rather than on exit status, which is 0 on both
      paths by design.
- [ ] Cases, each with the phase's success artifact present on disk:
      (1) handoff `.status` == expected → permits;
      (2) on-enum terminal mismatch (`blocked`) → refuses;
      (3) another phase's success value (`implemented` where `researched` expected) → refuses;
      (4) off-vocabulary (`success`) → permits, and the stderr names both `success` and all six
          legal values;
      (5) off-vocabulary (`research_complete`, the second live-incident value) → permits;
      (6) `in_progress` → permits, and its stderr does NOT use the off-schema/malformed framing;
      (7) handoff present with no `.status` key → permits;
      (8) handoff present but unparseable JSON → permits, no crash;
      (9) **parity assertion**: the same fixture directory with `.orchestrator-handoff.json`
          deleted → permits, and case (4)'s outcome is asserted equal to it;
      (10) the `partial` branch with an off-vocabulary status → permits, exercising the Phase 2
          consolidation;
      (11) the `partial` branch with `blocked` → refuses AND emits the refusal line (regression
          guard for the removed dry-run-only silence).
- [ ] Keep the suite free of task-number citations per
      `rules/no-task-references-in-deliverables.md` — it lives outside `specs/**`. Reference the
      behavior by name, not by task number.

**Timing**: 60 minutes

**Depends on**: 2

**Verification Tier**: local

**Scope Hypothesis**: eleven cases are asserted above. Confirm at implementation time that each is
actually reachable given the branch guards (`find_latest_artifact` must find an artifact, and the
`not_started` cases additionally require `artifact_newer_than_last_update`, so fixtures must stamp
`last_updated` older than the artifact mtime). If a case proves unreachable, record why in the test
file rather than deleting it silently.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` — new file.

**Verification**:
- The suite runs to completion and every case reports `[PASS]`.
- Deliberately reverting `handoff_permits_promotion()` to the old bare `==` in a scratch copy makes
  cases 4-9 fail — proving the suite actually guards the fix rather than passing vacuously.

---

### Phase 4: Final gate and rule-compliance sweep [NOT STARTED]

**Goal**: Run the full gate set and confirm the task's own stated verification bar plus the two
binding repository rules.

**Tasks**:
- [ ] Run `bash agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` and
      record the pass count in the summary.
- [ ] Run the sibling suites in `scripts/tests/` that could plausibly be affected, and record which
      were run and their outcomes.
- [ ] Run `bash agent-system/extensions/core/scripts/check-task-references.sh` (or the deployed
      equivalent) and confirm no new findings from the two touched files.
- [ ] Confirm `git status --short` shows changes ONLY under `agent-system/extensions/core/` and
      `specs/973_*/` — no `.claude/**` path may appear.
- [ ] Confirm the task's stated bar is met by direct demonstration, quoting the actual emitted
      stderr in the summary: an off-vocabulary handoff status produces the chosen behavior, it is
      at least as permissive as the same directory with the handoff removed, and the diagnostic
      names both the offending value and the legal set.
- [ ] Write the implementation summary under `specs/973_*/summaries/01_*.md`, explicitly recording
      the `in_progress` refinement as a departure from the research report's proposed code and why.

**Timing**: 30 minutes

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- `specs/973_recover_reconcile_from_malformed_handoff_status/summaries/01_*.md` — new summary.

**Verification**:
- All suite cases pass; the task-reference lint is clean; no `.claude/**` path is modified.
- The summary quotes real emitted output, not paraphrase.

---

## Testing & Validation

- [ ] `bash -n` and `shellcheck` clean (no new findings) on `reconcile-task-status.sh`.
- [ ] All eleven regression cases pass.
- [ ] Parity bar demonstrated: off-vocabulary status behaves identically to handoff-deleted.
- [ ] Diagnostic text names the offending value and all six legal values.
- [ ] `in_progress` diagnostic is distinct and does not call the value off-schema or malformed.
- [ ] On-enum terminal mismatches still refuse — no relaxation.
- [ ] Suite proven non-vacuous by reverting the fix in a scratch copy.
- [ ] No task-number citations in either touched file (both are outside `specs/**`).
- [ ] No file under `.claude/**` modified.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/reconcile-task-status.sh` (modified: helper rewrite,
  docstring, header note, `partial`-branch consolidation).
- `agent-system/extensions/core/scripts/tests/test-reconcile-handoff-status.sh` (new).
- `specs/973_recover_reconcile_from_malformed_handoff_status/summaries/01_*.md` (new).

## Rollback/Contingency

Both touched files are in one git-tracked directory with no build artifacts and no state
migration, so `git checkout` of the two paths restores the prior behavior exactly. The fix is
inert until the next `<leader>al` redeploy, so an in-repo revert before redeploy has no
propagation to reload. If the fix ships and proves too permissive in practice, the fallback is
NOT a revert to the old bare `==` (that restores the wedge) but a narrowing of the permit arm to
require corroborating evidence — for example, additionally requiring the phase artifact to
postdate `last_updated` via the existing `artifact_newer_than_last_update` helper before
permitting on an off-enum status. Record that as a follow-up task rather than re-tightening to the
original defect.
