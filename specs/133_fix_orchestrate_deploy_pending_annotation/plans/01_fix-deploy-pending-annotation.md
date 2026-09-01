# Implementation Plan: Register the ambient-binding defect class and fix the deploy-pending annotation

- **Task**: 133 - Register the ambient-binding defect class and fix the /orchestrate deploy-pending annotation
- **Status**: [IMPLEMENTING]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/133_fix_orchestrate_deploy_pending_annotation/reports/01_fix-deploy-pending-annotation.md
- **Artifacts**: plans/01_fix-deploy-pending-annotation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

This is a two-part task with load-bearing internal ordering. Part 1 registers a new
`AMBIENT_BINDING_MISMATCH` value in the closed system-defect vocabulary, in both places that
vocabulary lives (the recorder's `case` validator and the discrimination doc's instance table),
so the shape of defect this task exists to fix can be recorded at all. Part 2 fixes that defect:
`skill_postflight_update`'s exit-6 deploy-pending annotation block is guarded on an ambient
`TASK_DIR` environment variable that the `/orchestrate` caller never sets, so under
`/orchestrate` the guard is always false, `deploy_pending`/`deploy_pending_reason` never land in
the task's `.return-meta.json`, and only the unconditional `[deploy-check] deploy-pending: ...`
stderr line survives — the documented "defers loudly" contract in
`context/patterns/regeneration-is-manual-only.md` describes behavior that does not occur.

Definition of done: the new class is registered in both files in a single change; the task
directory is threaded into `skill_postflight_update` as an explicit optional parameter (removing
the ambient coupling rather than satisfying it); the three `/orchestrate` call sites pass it; a
regression test asserts the annotation lands on a genuine exit-6 refusal; and the motivating
incident is itself recorded to `specs/events.jsonl` under the new class — the recording that
previously failed with exit 1, "invalid --defect-class," is the end-to-end proof both parts
landed.

### Research Integration

The research report (`reports/01_fix-deploy-pending-annotation.md`) is integrated as follows:

- **Both open judgment calls are settled by this plan, following the report's recommendations**,
  with rationale recorded in the Decisions Recorded section below rather than rubber-stamped.
- **Correction of record carried forward**: the discrimination doc does **not** contain the
  literal word "thirteen" anywhere (verified zero-match grep). The implementer must not hunt for
  a count word to bump in that file. Only `system-defect-record.sh` carries the literal
  "thirteen" (2 occurrences). Phase 1 encodes this explicitly.
- **Caller audit re-confirmed**: 12 `skill_postflight_update` call sites repo-wide; only
  `orchestrate-stage5-postflight.sh`'s 3 sites run outside skill context. The other 9 sites need
  no change and must stay byte-for-byte identical.
- **Fixture reuse**: `test-postflight-deploy-gate.sh`'s "Case 1: overlap + STALE"
  (`build_fixture_repo` + `build_source_and_extensions`) is a working exit-6 driver to adapt, not
  reinvent. That file is **not** in this task's edit scope — it is a pattern source only.
- **Line numbers are not anchors**: `skill-base.sh` is being concurrently edited by sibling
  tasks; the guard already drifted from 536 to 537 during research. Every phase below anchors by
  function name and verbatim surrounding text.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was supplied for this dispatch; no ROADMAP.md consultation was performed.

## Cross-Task Contracts (binding)

This plan is one of several executing in parallel against overlapping files. The following are
binding on the implementer of this task.

### CONTRACT 1 — `skill_postflight_update` positional ownership

Current verified signature in `agent-system/extensions/core/scripts/skill-base.sh`:

| Position | Name | Status |
|----------|------|--------|
| 1 | `task_number` | required, existing |
| 2 | `operation` | required, existing |
| 3 | `session_id` | required, existing |
| 4 | `status` | required, existing |
| 5 | `phase_check_mode` | optional, existing (`local phase_check_mode="${5:-}"`) |
| 6 | `task_dir_override` | **optional, added by THIS task — owned here** |
| 7 | (reserved for the sibling phase-forcing-flags task) | not touched here |

**This task owns positional 6 and only positional 6.** It must not be renumbered, reordered, or
made required. Positional 7 is deliberately left free for the sibling task; this task must not
claim it. Every existing 4-argument and 5-argument call site continues to resolve `${6:-}` to
empty and fall back to `${TASK_DIR:-}`, preserving today's behavior byte-for-byte.

### CONTRACT 4 — precise, non-colliding change surface inside `skill_postflight_update`

A sibling task may add artifact-numbering increment logic to this same function. To compose
rather than collide, this task's edits inside `skill_postflight_update` are limited to exactly
three things and nothing else:

1. **Add** one `local` declaration, `local _task_dir="${6:-${TASK_DIR:-}}"`, immediately after
   the existing `phase_check_args` `if` block and before `local _t0`.
2. **Substitute** `${TASK_DIR:-}` / `${TASK_DIR}` with `${_task_dir}` at the four references
   **inside the `if [[ "$_postflight_rc" -eq 6 ]]` block only** (the guard condition, the two
   `jq` input/`mv` target paths, and the WARNING message path).
3. **Extend** the function's usage comment block above the definition to document the new
   optional 6th argument.

Explicitly **not** touched: the `skill_run_extension_hook "postflight" ... "${TASK_DIR:-}"` line
that follows the exit-6 block keeps its `${TASK_DIR:-}` reference unchanged. Rationale is
recorded under Decisions Recorded below.

### CONTRACT 7 — source-store boundary and task references

- Edit `agent-system/extensions/**` only. Never write to `.claude/**` — it is a gitignored,
  disposable deploy artifact regenerated from the source store.
- No task-number references in any deliverable outside `specs/**`. The events.jsonl record
  written in Phase 5 is under `specs/**` and is therefore exempt.

## Goals & Non-Goals

**Goals**:

- Register `AMBIENT_BINDING_MISMATCH` in the recorder validator **and** the discrimination doc
  table in one change, so the half-registered state that produces silent rejection never exists
  on disk.
- Remove the ambient `TASK_DIR` coupling from `skill_postflight_update`'s exit-6 annotation block
  by threading the task directory in as an explicit optional 6th positional argument.
- Make `/orchestrate`'s three `skill_postflight_update` call sites pass their already-bound
  `task_dir`.
- Add a regression test to `test-skill-base-lifecycle.sh` Group 4 asserting `deploy_pending: true`
  and a non-null `deploy_pending_reason` land in `.return-meta.json` on a genuine exit-6 refusal.
- Record the motivating incident to `specs/events.jsonl` under the new class as end-to-end proof.

**Non-Goals**:

- Do not change the completion-deploy gate's refusal logic or its exit-6 semantics.
- Do not alter what `update-task-status.sh` returns.
- Do not weaken the annotation block's best-effort, non-blocking character: a failed annotation
  must still never escalate past a warning.
- Do not wire an automated detector for the new class (additive registration with "not currently
  computed anywhere" is established precedent — four existing classes are registered that way).
- Do not restructure, rename, or renumber any existing defect class.
- Do not modify `test-postflight-deploy-gate.sh` — it is a pattern source, not an edit target.
- Do not make the new 6th parameter required, and do not touch positional 7.
- Do not regenerate or deploy `.claude/`.
- Do not reorder the deploy-first candidate resolution in `test-skill-base-lifecycle.sh` or any
  other suite. Deploy-first is *correct* for those suites — they exist to test what actually
  runs. Only a harness asking the different question "what does this pre-deploy source-store edit
  do?" may invert the order, and then only for the files under edit, with a header comment saying
  why.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent sibling edits to `skill-base.sh` shift line numbers mid-implementation | M | H | Anchor every edit by function name and verbatim surrounding text; re-locate by text search immediately before each edit; never cite a bare line number |
| Registering the class in only one of the two Part 1 files reproduces the exact silent-rejection failure being closed | H | M | Phase 1 is declared `Commit Mode: atomic-batch` — both files are one objective, intermediate half-registered states are not committed; Phase 5's events.jsonl recording is the end-to-end check that both landed |
| Positional collision with the sibling task on `skill_postflight_update` | H | M | CONTRACT 1 above assigns this task positional 6 and reserves 7; the sibling plan is checkable against this table |
| The regression test spuriously fails, or silently loads a mixed set of copies, because deploy-first resolution is a **chain of five composing loaders**, not one hop | M | H | Phase 4 tabulates all five loaders, determines this task's dependency span (source-store `skill-base.sh` only, verified — no new `lib/` dependency), and adds a first-running harness sanity check that exits 2 on a stale copy instead of emitting a misleading `[FAIL]` or "command not found" |
| A green `test-skill-base-lifecycle.sh` run is misreported as evidence about the source-store edit when it is actually regression assurance on the deployed copy | M | M | Phases 2 and 4 both state the distinction explicitly and require the summary to report the two routes separately |
| A future non-skill caller reintroduces the trap by neither passing arg 6 nor running through skill context | M | L | Inherent to the optional-parameter design (making it required would break 11 other call sites); accepted residual — the class registered in Phase 1 gives the next occurrence a name to record under |
| This task's own postflight is refused by the completion-deploy gate, since its `modified_files` overlap `agent-system/extensions/**` | L | H | Expected and self-referential, not a failure; after this task's fix the refusal annotates `.return-meta.json` correctly under `/orchestrate` instead of deferring silently |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3, 4 | 2 |
| 4 | 5 | 1, 2, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Register `AMBIENT_BINDING_MISMATCH` in both vocabulary sites [COMPLETED]

- **Goal:** Add the new defect class to the recorder's closed enum and the discrimination doc's
  instance table in a single atomic change, so `system-defect-record.sh --defect-class
  AMBIENT_BINDING_MISMATCH` stops exiting 1.

- **Tasks:**
  - [x] Re-verify the current enum by reading the `case "$defect_class" in ... esac` block in *(completed)*
        `agent-system/extensions/core/scripts/system-defect-record.sh` (currently the block whose
        preceding comment reads `--- Validate --defect-class against the closed, thirteen-value
        enum (fail loudly, write nothing) ---`). Confirm it lists exactly 13 values ending in
        `DEPLOY_ORPHAN_DRIFT`.
  - [x] Add `AMBIENT_BINDING_MISMATCH` to that `case` arm's alternation, after *(completed)*
        `DEPLOY_ORPHAN_DRIFT`, preserving the existing line-continuation formatting.
  - [x] Add `AMBIENT_BINDING_MISMATCH` to the `--defect-class CLASS   One of: ...` usage listing *(completed)*
        in the same file (the multi-line `One of:` block ending `HOOK_REGEX_BOUNDARY_DEFECT|DEPLOY_ORPHAN_DRIFT`).
  - [x] Update both literal "thirteen" occurrences in this file to "fourteen": the header usage *(completed)*
        comment (`One of the thirteen Signal A instances`) and the `*)` arm's error message
        (`must be one of the thirteen Signal A instances`). Also update the validator block's own
        preceding comment (`closed, thirteen-value enum`) to `fourteen-value`.
  - [x] Confirm by grep that no "thirteen" remains in *(completed)*
        `agent-system/extensions/core/scripts/system-defect-record.sh`.
  - [x] In `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`, add *(completed)*
        one new row to the Signal A instance table (the table whose rows currently run
        `OFF_SCHEMA_STATUS` through `DEPLOY_ORPHAN_DRIFT`), immediately after the
        `DEPLOY_ORPHAN_DRIFT` row. Name the **mechanism**, matching every existing row's voice:
        a downstream guard keyed to an ambient/global shell variable that only some callers
        populate, so the guard's condition silently evaluates false instead of erroring.
        Detection column: `**not currently computed anywhere**`.
  - [x] Add one new short paragraph to the doc **after** the existing "A further three instances *(completed)*
        (`SESSION_LOCK_CONTENTION`, `HOOK_REGEX_BOUNDARY_DEFECT`, ...)" paragraph, in that
        paragraph's established voice, narrating the single new instance and stating that none of
        the thirteen pre-existing instances was reworded or reinterpreted to cover it. Do **not**
        search for an existing "thirteen" in this file to edit — there is none; this paragraph is
        where the word first appears here.
  - [x] Verify registration end-to-end at the recorder level: *(completed)*
        `bash agent-system/extensions/core/scripts/system-defect-record.sh --help` still exits 0
        and lists the new class; an invalid class name still exits 1.

- **Timing:** 45 minutes

- **Depends on:** none

- **Verification Tier:** local

- **Commit Mode:** atomic-batch

  Justification: the two files are one objective. A commit containing only the recorder change or
  only the doc change is precisely the half-registered state this work exists to eliminate — the
  intermediate is not merely untidy, it reproduces the defect. Both files land in one commit; no
  intermediate single-file state is committed.

- **Scope Hypothesis:** Asserted at plan time, to be confirmed at implementation time before
  editing: (a) the recorder's `case` enum holds exactly **13** values; (b) the discrimination
  doc's instance table holds exactly **13** data rows; (c) the literal string "thirteen" occurs
  exactly **2** times in `system-defect-record.sh` plus **1** more in the validator block comment
  (`thirteen-value`), and **0** times in `system-defect-discrimination.md`; (d) no other file
  under `agent-system/extensions/core/` carries a defect-class count word. Confirm with
  `grep -c` on the enum arm, a row count on the table, and
  `grep -rn "thirteen" agent-system/extensions/core/` before editing. If any count differs,
  reconcile against the tree rather than against this plan.

- **Files to modify:**
  - `agent-system/extensions/core/scripts/system-defect-record.sh` — add the enum value to the
    `case` arm and the `One of:` usage listing; update the count word at all occurrences.
  - `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — add one
    table row and one narrating paragraph.

- **Verification:**
  - `grep -n "AMBIENT_BINDING_MISMATCH"` returns hits in **both** files.
  - `grep -rn "thirteen" agent-system/extensions/core/scripts/system-defect-record.sh` returns
    zero matches.
  - The doc's instance table has 14 data rows.
  - Invoking the recorder with an unknown class still exits 1 with the (now "fourteen") error
    message, proving the validator was not accidentally opened up.

---

### Phase 2: Add the optional 6th `task_dir_override` parameter to `skill_postflight_update` [COMPLETED]

- **Goal:** Remove the ambient-variable coupling at its root by giving
  `skill_postflight_update` an explicit, optional task-directory argument that defaults to
  today's ambient value, leaving all 12 existing call sites behaviorally unchanged.

- **Tasks:**
  - [x] Re-locate `skill_postflight_update` in *(completed)*
        `agent-system/extensions/core/scripts/skill-base.sh` by function name (not line number)
        and read its current body; confirm the `phase_check_mode="${5:-}"` /
        `phase_check_args` block and the `if [[ "$_postflight_rc" -eq 6 ]]` block are present as
        described in this plan. If a sibling task has already altered the function, reconcile
        against the tree and re-check CONTRACT 1 before proceeding.
  - [x] Add `local _task_dir="${6:-${TASK_DIR:-}}"` immediately after the closing `fi` of the *(completed)*
        `phase_check_args` block and before `local _t0`, with a short comment documenting that
        this is the optional 6th positional, that it defaults to the ambient `TASK_DIR` so every
        existing 4-arg and 5-arg caller is unchanged, and that it exists so non-skill callers
        (which never run `skill_validate_input` and therefore never have `TASK_DIR` set) can
        reach the annotation block.
  - [x] Extend the `# Usage: skill_postflight_update "$task_number" "$operation" "$session_id" *(completed)*
        "$status"` comment above the function to document arguments 5 and 6, naming argument 6 as
        optional and stating its `${TASK_DIR:-}` default.
  - [x] Inside the `if [[ "$_postflight_rc" -eq 6 ]]` block **only**, replace each `${TASK_DIR:-}` *(completed)*
        / `${TASK_DIR}` reference with `${_task_dir}`: the guard condition
        `[[ -n "${TASK_DIR:-}" && -f "${TASK_DIR}/.return-meta.json" ]]`, the `jq` input path, the
        `mv` destination path, and the WARNING message's path interpolation.
  - [x] Leave the `skill_run_extension_hook "postflight" ... "${TASK_DIR:-}"` line that follows *(completed)*
        the block **unchanged** (see Decisions Recorded).
  - [x] Confirm no other function in `skill-base.sh` was touched. *(completed)*
  - [x] `bash -n agent-system/extensions/core/scripts/skill-base.sh` passes. *(completed)*

- **Timing:** 30 minutes

- **Depends on:** 1

  The code change is technically independent of Phase 1, but the task specifies Part 1 lands
  first, and Phase 5's end-to-end recording of this very defect requires the class to already
  exist. Sequencing here keeps the recorded history in the order the incident is narrated.

- **Verification Tier:** interface

  Justification: this changes the arity of a function whose call sites span 10 files. The change
  is purely additive and every existing call site is expected unchanged, but per the tie-break
  rule the stricter applicable tier governs: build/lint the changed file plus enumerate and
  re-check its direct dependents (the 12 call sites).

- **Scope Hypothesis:** Asserted at plan time: there are exactly **12** `skill_postflight_update`
  call sites repo-wide across 10 files, of which **3** (all in
  `orchestrate-stage5-postflight.sh`) require a change and **9** must remain byte-for-byte
  identical; exactly **1** of the 12 currently passes a 5th argument (the implement branch's
  `"warn"`). Confirm at implementation time with
  `grep -rn "skill_postflight_update" agent-system/extensions/` before and after editing, and
  verify the non-orchestrate call sites are absent from `git diff --stat`.

- **Files to modify:**
  - `agent-system/extensions/core/scripts/skill-base.sh` — one added `local`, one extended usage
    comment, four in-block variable substitutions. Nothing else.

- **Verification:**
  - `bash -n` on the file passes.
  - `git diff` on `skill-base.sh` shows changes confined to `skill_postflight_update` and its
    immediately preceding comment block.
  - `grep -rn "skill_postflight_update" agent-system/extensions/` still returns 12 sites; the 9
    non-orchestrate sites are untouched in the diff.
  - Re-run `test-skill-base-lifecycle.sh`'s existing Group 4 cases. **Report the result for what
    it is**: under a stale deploy this suite sources the *deployed* `skill-base.sh`, so a green
    run is regression assurance that the deployed copy still works — it is **not** evidence about
    the source-store edit made in this phase. Evidence about the edit comes only from the
    source-store harness described in Phase 4. Do not let a green suite run be recorded as a
    check on the new parameter.
  - Confirm by reading the diff that the 4-argument default path resolves `${6:-${TASK_DIR:-}}`
    to the same value it had before the change.

---

### Phase 3: Pass `task_dir` at the three `/orchestrate` call sites [COMPLETED]

- **Goal:** Make the `/orchestrate` postflight path actually reach the annotation block by
  forwarding the task directory it already has bound.

- **Tasks:**
  - [x] Re-locate the three `skill_postflight_update` calls in *(completed)*
        `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh` by their
        surrounding branch text (the research, plan, and implement branches), not by line number.
  - [x] Research branch: append `"$task_dir"` as the 6th argument. Because positional 5 *(completed)*
        (`phase_check_mode`) is not passed at this site, an explicit empty 5th argument `""` must
        be inserted before it so positional 6 lands in position 6 —
        `skill_postflight_update "$task_number" "research" "$session_id" "$dispatch_status" "" "$task_dir"`.
        An empty 5th argument is behaviorally identical to omitting it: the callee's
        `phase_check_mode="${5:-}"` yields the empty string either way, and the
        `if [[ -n "$phase_check_mode" ]]` guard leaves `phase_check_args` empty, so no
        `--phase-check` flag is passed.
  - [x] Plan branch: same treatment. *(completed)*
  - [x] Implement branch: this site already passes `"warn"` as the 5th argument, so append *(completed)*
        `"$task_dir"` directly as the 6th —
        `skill_postflight_update "$task_number" "implement" "$session_id" "$dispatch_status" "warn" "$task_dir"`.
  - [x] Confirm `task_dir` is in scope at all three sites (bound as `task_dir="${4:-}"` in the *(completed)*
        script's arg-parsing preamble) and that the script still never sets or exports a variable
        named `TASK_DIR` — the fix removes the dependency rather than satisfying it.
  - [x] Confirm the deliberate non-call site (the branch whose comment reads `Deliberately NO *(completed)*
        skill_postflight_update call`) is untouched.
  - [x] `bash -n agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh` passes. *(completed)*

- **Timing:** 30 minutes

- **Depends on:** 2

- **Verification Tier:** local

  Justification: edits are confined to one file and change no externally visible signature —
  they are call-site argument additions against a signature already established in Phase 2.

- **Scope Hypothesis:** Asserted at plan time: exactly **3** `skill_postflight_update` call sites
  exist in this file (research, plan, implement branches), of which exactly **1** already passes
  a 5th argument. Confirm with `grep -n "skill_postflight_update"` on the file before editing; if
  the count differs, reconcile against the tree.

- **Files to modify:**
  - `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh` — three call-site
    argument additions.

- **Verification:**
  - `bash -n` passes.
  - All three calls now pass 6 positional arguments; the implement branch still passes `"warn"`
    in position 5.
  - `grep -n "TASK_DIR" agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh`
    returns zero matches — the uppercase ambient variable is still never set here, confirming the
    coupling was removed rather than papered over.

---

### Phase 4: Regression test for the exit-6 annotation [COMPLETED]

- **Goal:** Assert mechanically that on a genuine exit-6 refusal, `deploy_pending: true` and a
  non-null `deploy_pending_reason` land in the task's `.return-meta.json` when the task directory
  is supplied via the new 6th argument.

- **Tasks:**
  - [x] Read `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh`'s *(completed)*
        `build_fixture_repo` and `build_source_and_extensions` helpers and its "Case 1: overlap +
        STALE" case. Adapt the technique; do **not** modify that file.
  - [x] Add the new case(s) to `test-skill-base-lifecycle.sh`'s existing **Group 4** *(completed)*
        (`skill_preflight_update` / `skill_postflight_update`), after the existing non-success-status
        case and before or alongside the implement-target case, following that group's existing
        `cd`-into-fixture discipline. Do **not** introduce a `SKILL_REPO_ROOT` override for these
        cases — the suite's own header records that these two functions hardcode the bare relative
        path `.claude/scripts/update-task-status.sh` and therefore require a full isolated fixture
        repo that the test `cd`s into.
  - [x] Extend that group's fixture (or build a sibling fixture in the same style) so *(completed)*
        `update-task-status.sh`'s completion-deploy gate genuinely returns 6: `modified_files`
        overlapping `agent-system/extensions/**` plus a fabricated `.claude-extensions.json` and
        throwaway source-store git repo producing `deploy_freshness_status: STALE`, exactly as
        `build_source_and_extensions` does.
  - [x] Place a `.return-meta.json` in the fixture task directory before the call. *(completed)*
  - [x] **Primary case**: call `skill_postflight_update <n> "implement" "<sess>" "implemented" "" *(completed)*
        "<fixture task dir>"` with `TASK_DIR` **unset** in the environment (the `/orchestrate`
        condition). Assert: return code is 6; `.return-meta.json` gains `deploy_pending == true`;
        `deploy_pending_reason` is a non-null, non-empty string.
  - [x] **Regression-guard case**: with the 6th argument omitted and `TASK_DIR` exported to the *(completed)*
        same fixture directory (the legacy skill-context path), assert the annotation still lands
        — proving the default `${6:-${TASK_DIR:-}}` preserves existing behavior.
  - [x] **Non-blocking case**: with neither the 6th argument nor `TASK_DIR` set, assert the *(completed)*
        function still returns 6 and does not error or crash — the block stays best-effort.
  - [x] Add a **harness sanity check that runs first and exits 2 (environment error) rather than *(completed)*
        reporting a test failure**, matching the suite's existing exit-2 convention for "a
        required library/script was not found." It must assert, before any case executes, that
        the `skill-base.sh` actually sourced contains the Phase 2 change (`grep -q '_task_dir'`
        against `$SKILL_BASE`) and that `skill_postflight_update` is a defined function. A stale
        deployed copy must produce a named environment error naming the stale path — never a
        `[FAIL]` line, and never a bare "command not found."
  - [x] Confirm the suite's end-of-run contamination guard still reports no delta against *(completed)*
        `BASELINE_SPECS_STATUS` (the new cases must not touch the real `specs/` tree).
  - [x] Run the full suite and confirm exit 0, then record separately which of the two routes *(completed)*
        (deployed suite / source-store harness) produced the evidence for the new cases.

- **Timing:** 1 hour 15 minutes

- **Depends on:** 2

  The test exercises `skill_postflight_update` directly, not the orchestrate script, so it is
  independent of Phase 3 and may run in parallel with it.

- **Verification Tier:** full

  Justification: the phase's deliverable *is* verification of runtime behavior of a shared
  lifecycle function; the complete suite is the gate, and the tie-break rule pushes an
  uncertain runtime-behavior phase to the ceiling.

- **Scope Hypothesis:** Asserted at plan time: **3** new cases are added, all inside the existing
  Group 4, with **0** new test files created and **0** edits to
  `test-postflight-deploy-gate.sh`. Confirm at implementation time via `git diff --stat` over
  `agent-system/extensions/core/scripts/tests/`.

- **Files to modify:**
  - `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — new Group 4 cases
    plus whatever fixture helper the new cases need, in the file's existing style.

- **Verification under a stale deploy (read before running the suite):**

  Deploy-first resolution is not a single hop — it is a **chain of five loaders that compose**,
  so a partial fix can silently load a mixed set of copies, or surface as a confusing "command
  not found" on a newly added function rather than a clean signal:

  | Loader | Resolves |
  |---|---|
  | `test-skill-base-lifecycle.sh` | `$REPO_ROOT/.claude/scripts/skill-base.sh` -> `$SCRIPT_DIR/../skill-base.sh` |
  | `test-status-vocabulary.sh` | `.claude/scripts/lib/status-vocabulary.sh` -> source store |
  | `update-task-status.sh` | `.claude/scripts/lib/` -> source store |
  | `skill-base.sh` (for `lib/common.sh`) | `${SKILL_REPO_ROOT}/.claude/` -> `$(dirname BASH_SOURCE)/lib/` |
  | `orchestrate-stage5-postflight.sh` (for `skill-base.sh`) | cwd `.claude/` -> `$REPO_ROOT/.claude/` -> `$SCRIPT_DIR/` |

  **Dependency-span determination for this task: the harness needs the source-store
  `skill-base.sh` and nothing else from the source store.** This is verified, not assumed:

  - The Phase 2 edit adds one `local` whose value is pure parameter expansion
    (`"${6:-${TASK_DIR:-}}"`) plus in-block variable substitutions. It introduces **no new
    `lib/` dependency and calls no new function**.
  - Everything the exit-6 block itself invokes is a shell builtin or a plain external
    (`mktemp`, `jq`, `mv`, `rm`, `echo`).
  - The two helpers `skill_postflight_update` calls after the block —
    `skill_run_extension_hook` and `_events_append_observable` — are both defined **inside
    `skill-base.sh` itself**, not in `lib/common.sh`, so sourcing the source-store copy brings
    them along.
  - `update-task-status.sh` and its `lib/` chain supply the exit-6 rc and are **not modified by
    this task**, so taking them from the deployed tree (as `build_fixture_repo` already does) is
    correct, not a compromise. The mixed load is deliberate: source-store copy of the one file
    under edit, deployed copies of everything else.

  Therefore option 1 applies and the harness stays a single-file override. Concretely:

  1. `grep -c '_task_dir' "$(git rev-parse --show-toplevel)/.claude/scripts/skill-base.sh"` — a
     zero count means the deployed copy predates Phase 2, so the suite is testing the old code.
  2. In that case, verify the new cases with a throwaway harness in the scratchpad directory that
     sources `agent-system/extensions/core/scripts/skill-base.sh` explicitly and re-executes the
     same fixture steps and assertions. Record in the implementation summary which route was used.
  3. **Do not pre-export `SKILL_REPO_ROOT` before sourcing the source-store copy.** Left unset, it
     auto-derives from `BASH_SOURCE` to `agent-system/extensions`, which has no `.claude/`, so the
     `lib/common.sh` load falls through to the source-store copy — coherent. Pre-exporting it to
     the fixture root would instead pull the fixture's deployed-copy `common.sh` under a
     source-store `skill-base.sh`. Both loads are behaviorally equivalent here (this task does not
     modify `common.sh`), so this is a coherence precaution, not a correctness bug — stated so a
     reader does not chase it as one.
  4. Do **not** deploy or regenerate `.claude/` to make the suite pass, and do **not** reorder the
     suite's candidate resolution. Deploy-first is out of scope here not merely because the suite
     is another task's territory, but because deploy-first is *correct for that suite*: it exists
     to test what actually runs. A harness asking what a pre-deploy source-store edit does is
     answering a different question, and should invert the order **only for the files under edit**,
     with a header comment saying why.

- **Reporting obligation:** a green `test-skill-base-lifecycle.sh` run is regression assurance on
  the **deployed** copy, not evidence about the source-store edit. The implementation summary must
  report it as exactly that, and must separately name the source-store harness result as the
  evidence for the new behavior. Conflating the two would be a fresh instance of the same
  silent-success reporting failure this task exists to close.

- **Verification:**
  - The full `test-skill-base-lifecycle.sh` run (or the source-store harness, per the note above)
    exits 0 with the three new cases passing.
  - Each new case asserts on the actual `.return-meta.json` contents via `jq`, not on stderr text.
  - The suite's specs/-contamination guard reports no new delta.

---

### Phase 5: Record the motivating incident under the new class [COMPLETED]

- **Goal:** Close the loop end-to-end by recording, to `specs/events.jsonl`, the exact incident
  whose recording previously failed with exit 1, "invalid --defect-class."

- **Tasks:**
  - [x] Read `agent-system/extensions/core/scripts/system-defect-record.sh`'s usage block to *(completed)*
        confirm the required flags and their current spellings before invoking it.
  - [x] Invoke the recorder with `--defect-class AMBIENT_BINDING_MISMATCH`, attributing the defect
        to `scripts/skill-base.sh` (the guard site) and/or
        `scripts/orchestrate-stage5-postflight.sh` (the caller site), with a description naming
        the mechanism: the exit-6 annotation guard read an ambient `TASK_DIR` that the
        `/orchestrate` caller never set, so the guard silently evaluated false and the documented
        `deploy_pending` marker never landed. *(completed: follow-up invocation after the
        inter-cycle redeploy landed Phase 1's class registration in the deployed
        `.claude/scripts/system-defect-record.sh`; event_id `evt_1788290690039_Ld0M8J`)*
  - [x] Confirm the invocation exits **0** (previously exit 1) and that a corresponding record
        appears in `specs/events.jsonl`. *(completed: exit 0, confirmed)*
  - [x] Confirm the recorder wrote a well-formed JSON line: `tail -1 specs/events.jsonl | jq .`
        parses and the `defect_key`/detail carries the new class name. *(completed: parses;
        `defect_key: "AMBIENT_BINDING_MISMATCH:agent-system/extensions/core/scripts/skill-base.sh"`)*

**Phase 5 blocker (discovered during implementation, not anticipated by the plan or its research
report)**: `system-defect-record.sh` sources `deploy-root-guard.sh` (line 197, after argument
validation but before any write), which structurally requires the invoking script's own directory
to end in `/.claude` or `/.opencode` — i.e. it is, by design, **NOT RUNNABLE FROM THE SOURCE
STORE** (the script's own header says so explicitly). Verified: an invocation from
`agent-system/extensions/core/scripts/system-defect-record.sh` past the point where an unknown
`--defect-class` would be rejected exits 1 from this guard, naming the source-store path as the
cause. The only path that satisfies the guard is the **deployed** copy,
`.claude/scripts/system-defect-record.sh` — and PROJECT_ROOT is derived structurally as two
literal directory levels above that script's own on-disk location
(`common_repo_root "$SCRIPT_DIR" 2`, no `git rev-parse` fallback), so there is no way to satisfy
the guard from a location other than the real `.claude/scripts/` that also resolves PROJECT_ROOT
to the real repo root (any other `.claude`-shaped directory two levels below some other root
would misdirect the `specs/events.jsonl` write). The real deployed copy currently predates this
task's Phase 1 change (`grep -c AMBIENT_BINDING_MISMATCH .claude/scripts/system-defect-record.sh`
returns 0) and therefore does not yet recognize the new class.

Closing this gap requires either running the deploy/regeneration step, or hand-authoring
`.claude/**`, and **both are explicitly prohibited**: this plan's own Non-Goals state "Do not
regenerate or deploy `.claude/`," and the repo-wide
`.claude/rules/source-store-deploy-boundary.md` rule prohibits hand-authoring `.claude/**` files
regardless of task. Neither prohibition is this task's to waive. This phase is therefore left
`[PARTIAL]` rather than forced through a prohibited workaround or a hand-edited `events.jsonl`
line (the plan's own Files-to-modify note for this phase states the file is "never hand-edited").
**Resolved**: a later `/orchestrate` cycle ran the sanctioned inter-cycle redeploy checkpoint
(`deploy-headless.sh`), regenerating `.claude/` from `agent-system/extensions/**` and landing
Phase 1's `AMBIENT_BINDING_MISMATCH` class registration in the deployed
`.claude/scripts/system-defect-record.sh` (verified via
`grep -c AMBIENT_BINDING_MISMATCH .claude/scripts/system-defect-record.sh` returning 2). The
follow-up command recorded in the phase-5 progress file's `follow_up_command` field was then run
against the deployed copy, exiting 0 and appending event_id `evt_1788290690039_Ld0M8J` to
`specs/events.jsonl` with `defect_class: "AMBIENT_BINDING_MISMATCH"` and `task: 133`.

- **Timing:** 30 minutes

- **Depends on:** 1, 2, 3, 4

- **Verification Tier:** local

  Justification: this phase runs an existing script and appends one line to a `specs/**` data
  file; it changes no code and has no compile or interface surface. `local` rather than `prose`
  because the recorder is genuinely executed and its exit code is the assertion.

- **Files to modify:**
  - `specs/events.jsonl` — one appended record, written by the recorder script (never hand-edited).

- **Verification:**
  - The recorder exits 0 where it previously exited 1 with "invalid --defect-class" — this is the
    end-to-end proof that Phase 1 registered the class in the validator, not just the doc.
  - `tail -1 specs/events.jsonl | jq .` parses and names `AMBIENT_BINDING_MISMATCH`.

---

## Decisions Recorded

The task asked for both open judgment calls to be weighed and recorded, not rubber-stamped.

### Class name: `AMBIENT_BINDING_MISMATCH`, not an observability-marker framing

**Decision: `AMBIENT_BINDING_MISMATCH`.** Every one of the 13 existing table entries names the
failure **mechanism**, never the motivating instance — `HOOK_REGEX_BOUNDARY_DEFECT` names "an
unstated boundary assumption," not the specific digit-count quantifier bug that prompted it;
`DEPLOY_ORPHAN_DRIFT` names "purely-additive deploy with no pruning," not the one stray index
entry. The mechanism here is a callee guard keyed to an ambient shell variable that only some
callers happen to populate, so the guard evaluates false instead of erroring — a shape that can
recur at any guard reading an unexported convenience variable.

The competing framing (`OBSERVABILITY_MARKER_UNREACHED` or similar) is a legitimate alternative
and was genuinely weighed: it has the advantage of naming what a reader actually notices first
(a documented marker that never appears). It is **rejected** because it names the symptom rather
than the cause, breaks the table's uniform naming convention, and is narrower — an unreached
observability marker is only one of the outcomes an ambient-binding mismatch can produce; the
same mechanism could just as easily silently skip a cleanup step or a lock release, neither of
which is an observability marker at all. Naming by symptom would leave those cases unclassified.

Overlap check: `AMBIENT_BINDING_MISMATCH` does not subsume `SESSION_LOCK_CONTENTION` (a
specifically session-id keying mismatch between two registration sites, narrower and
differently-shaped) nor any other existing class.

No detector is wired at registration, matching the established precedent of
`ARTIFACTS_MISSING_ON_SUCCESS`, `SESSION_LOCK_CONTENTION`, `HOOK_REGEX_BOUNDARY_DEFECT`, and
`DEPLOY_ORPHAN_DRIFT`, all four registered as "not currently computed anywhere."

### Fix approach: option (b), the additive parameter, not option (a), exporting `TASK_DIR`

**Decision: option (b).** Option (a) — `export TASK_DIR` in
`orchestrate-stage5-postflight.sh` before each call — is a strictly smaller diff touching one
file, and it would work. It is **rejected** because it satisfies the ambient coupling instead of
removing it: `skill_postflight_update` would continue to depend on an environment variable it
does not declare as an argument, so the identical silent-false failure remains one missed
`export` away at the next non-skill caller (a future standalone script, a test harness, another
orchestration entry point). The whole reason this defect went undiagnosed is that a false guard
condition produces no error — that property does not change under option (a).

Option (b)'s cost was checked and is low: `phase_check_mode` is already the optional 5th
argument, so a 6th is purely additive. Nine of the twelve call sites need no change at all, and
the three that do already have `task_dir` in scope. The residual weakness — the parameter is
optional, so a future caller can still omit it and fall back to the ambient default — is
accepted deliberately: making it required would break all nine other call sites for no gain, and
the class registered in Phase 1 gives any recurrence a name to be recorded under.

### The `skill_run_extension_hook` line keeps `${TASK_DIR:-}` unchanged

**Decision: do not substitute `_task_dir` into the postflight extension-hook invocation.** It is
tempting for consistency, but the hook call is a separate contract with its own consumers, and
changing it would mean extension postflight hooks start receiving a non-empty task directory
under `/orchestrate` where they previously received an empty string — a behavior change to
third-party hook code that is outside this task's scope and unverified by any test here. The
narrow substitution inside the exit-6 block is exactly the fix the task asks for; widening it is
a separate decision for a separate task. This also minimizes the diff surface shared with the
sibling task editing this same function (CONTRACT 4).

## Testing & Validation

- [x] `bash -n` passes on all three modified shell scripts. *(completed: also re-checked on the
      4th shell script this phasing added, test-skill-base-lifecycle.sh)*
- [x] `grep -n "AMBIENT_BINDING_MISMATCH"` returns hits in both the recorder and the *(completed)*
      discrimination doc — never in only one.
- [x] Zero occurrences of "thirteen" remain in `system-defect-record.sh`. *(completed)*
- [x] The discrimination doc's Signal A instance table has 14 data rows. *(completed)*
- [x] `grep -rn "skill_postflight_update" agent-system/extensions/` still returns 12 call sites; *(completed: verified via git diff --stat scope instead of a literal count -- the plan's own bare grep pattern also matches prose/doc mentions and test files, making a literal "12" ambiguous; git diff --stat over the whole repo confirms only skill-base.sh and orchestrate-stage5-postflight.sh changed among files referencing this function, so every other site is unmodified)*
      the 9 non-orchestrate sites are absent from the diff.
- [x] `grep -n "TASK_DIR" agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh` *(completed)*
      returns zero matches.
- [x] `test-skill-base-lifecycle.sh` exits 0 with the three new Group 4 cases passing (or the *(completed: via the source-store scratchpad harness -- 28 passed, 0 failed; the deployed-suite route correctly exits 2 against the stale deployed copy, which is the harness sanity check working as designed)*
      documented source-store harness route, if the deployed tree is stale — record which).
- [x] The new harness sanity check runs first and exits 2 on a stale `skill-base.sh`, rather than *(completed)*
      emitting a `[FAIL]` line or a bare "command not found".
- [x] The summary reports the deployed-suite result and the source-store harness result *(completed)*
      **separately**, and does not present a green deployed-suite run as evidence about the
      source-store edit.
- [x] The suite's specs/-contamination guard reports no delta against its baseline. *(completed)*
- [x] `test-postflight-deploy-gate.sh` remains unmodified (`git diff --stat` shows no entry). *(completed)*
- [ ] `system-defect-record.sh --defect-class AMBIENT_BINDING_MISMATCH ...` exits 0 and appends a
      `jq`-parseable line to `specs/events.jsonl`. *(deviation: deferred -- see the plan's "Phase 5
      blocker" note; blocked by deploy-root-guard.sh, not by this task's own code)*
- [x] No file under `.claude/**` was written. *(completed)*
- [x] No task-number reference appears in any changed file outside `specs/**`. *(completed: grep
      confirmed no "task 133" additions in any of the five modified source-store files)*

## Artifacts & Outputs

- `specs/133_fix_orchestrate_deploy_pending_annotation/plans/01_fix-deploy-pending-annotation.md`
  (this file)
- `specs/133_fix_orchestrate_deploy_pending_annotation/summaries/01_fix-deploy-pending-annotation-summary.md`
  (produced at implementation time)
- Modified: `agent-system/extensions/core/scripts/system-defect-record.sh`
- Modified: `agent-system/extensions/core/context/patterns/system-defect-discrimination.md`
- Modified: `agent-system/extensions/core/scripts/skill-base.sh`
- Modified: `agent-system/extensions/core/scripts/orchestrate-stage5-postflight.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh`
- Appended: `specs/events.jsonl` (one `AMBIENT_BINDING_MISMATCH` record)

## Rollback/Contingency

Every phase is a small, independently revertible commit against the source store; no deploy is
performed, so nothing in `.claude/**` needs unwinding.

- **Phase 1** reverts cleanly as a unit (atomic-batch, both files in one commit). Reverting it
  restores the 13-value enum; any events.jsonl record already written under the new class becomes
  an orphaned class name in the log — harmless, since the log is append-only history, but Phase 5
  should be reverted first if the whole task is being backed out.
- **Phases 2 and 3** revert independently. Reverting Phase 3 alone leaves the new parameter in
  place, unused — behavior returns to today's exactly, since every call site falls back to
  `${TASK_DIR:-}`. Reverting Phase 2 requires reverting Phase 3 first, or the orchestrate call
  sites would pass an argument the callee ignores (harmless in bash, but incoherent).
- **Phase 4** reverts independently; removing the new test cases restores the prior suite.
- **Phase 5** cannot be "reverted" in the ordinary sense — `specs/events.jsonl` is append-only.
  If the record proves wrong, record a correction rather than editing the line out.

Contingency if the regression test cannot be made to drive a genuine exit-6 refusal inside the
fixture within the phase's time budget: land Phases 1-3 and 5 (the substantive fix and its
end-to-end proof), mark Phase 4 `[PARTIAL]` with the specific fixture obstacle recorded, and do
not weaken the assertions to something the fixture can satisfy trivially. A test that passes
without genuinely reaching exit 6 is worse than no test — it is a second silent-success surface
of exactly the kind this task exists to eliminate.
