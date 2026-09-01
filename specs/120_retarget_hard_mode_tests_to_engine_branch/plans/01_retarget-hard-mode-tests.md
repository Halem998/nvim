# Implementation Plan: Retarget Hard-Mode Tests to the Merged Engine's hard_mode Branch

- **Task**: 120 - Retarget hard mode tests to engine branch
- **Status**: [IMPLEMENTING]
- **Effort**: 8 hours
- **Dependencies**: 118, 119 (both `[COMPLETED]`); plus the H4-gate-port task (batch Contract 5 — must land before Phase 1 runs; see "Ordering Contract" below)
- **Research Inputs**: specs/120_retarget_hard_mode_tests_to_engine_branch/reports/01_retarget-hard-mode-tests.md
- **Artifacts**: plans/01_retarget-hard-mode-tests.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Seven test/lint files under `agent-system/extensions/core/scripts/tests/**` and `scripts/lint/**`
currently anchor fixtures and assertions on `skill-orchestrate-hard/SKILL.md`. That file's
mechanisms have been merged into `skill-orchestrate/SKILL.md` as `hard_mode`-gated (and in three
cases now-unconditional) branches, and the `-hard` file is scheduled for deletion by a separate,
dependent task. This plan retargets all seven so their coverage survives that deletion rather than
being silently dropped.

Five files are close to mechanical path/label swaps; two (`test-handoff-reader-parity.sh`,
`test-routing-resolution.sh` Assert 3) lose their "diff two engine files" premise entirely and need
genuine logic rewrites. Four additional defects not identified during research were found while
planning and are folded into the phases below. Definition of done: all seven files target
`skill-orchestrate/SKILL.md` only, the full suite passes, and a per-file mutation check confirms
each retargeted file still fails when the bug it guards is reintroduced.

### Research Integration

The research report's per-file findings drive Phases 2-7 directly: which files are mechanical
(items 4, 5, 6, 7 of its Recommendations list), which need rewrites (items 6 and 7), and the one
semantic drift it found — `test-loop-guard-budget-override.sh` Case 4's `guard_session_id`
mismatch INFO-log assertion, gated on `engine_label == "base"` against code that is now
unconditional in the merged file. That fix is Phase 5's centre of gravity, not an afterthought.

Four findings were established during planning that the research pass did not surface. Each is
verified, not speculative, and each is assigned to a phase:

1. **`lint-contract-compliance.sh` carries a second hard-engine reference, not just Check D.**
   `check_c_*`'s tail block sets `orchestrate_skill="$CORE_ROOT/skills/skill-orchestrate-hard/SKILL.md"`
   and asserts the file *exists*. Once the sibling deletion task removes that file this assertion
   starts failing outright. Research scoped this file to Check D only; both sites must be
   retargeted. (Phase 2)
2. **A naive path swap breaks `test-loop-guard-staleness.sh`'s "exactly one marker" assertion.**
   The test counts `grep -c 'loop-guard-staleness:begin'`. In the merged file that bare string
   matches **two** lines: the real sentinel, and a design-decision table row near the top of the
   file that names the sentinel in prose. The assertion expects exactly 1 and would fail against
   a correct merged file. Fix: count the full sentinel comment form
   `# --- loop-guard-staleness:begin ---` with `grep -cF`. Verified unique (begin=1, end=1) for
   all four sentinels in the merged file — so this hardening is safe to apply uniformly. (Phase 3)
3. **`test-handoff-reader-parity.sh` contains a second, undocumented base-vs-hard comparison.**
   Beyond the Stage 5 field parity the research describes, the file also extracts the
   `dispatch-seq-gate:begin/:end` sentinel region from both engines and diffs them through a
   `s/skill-orchestrate-hard/skill-orchestrate/g` normalization. With one engine this compares a
   file to itself and passes vacuously. That coverage already lives in
   `test-handoff-dispatch-identity.sh`; the block must be removed deliberately, not left as a
   green no-op. (Phase 7)
4. **`test-resume-scan-nonconformance.sh` Site A derives line numbers by `grep -n ... | head -1`
   across the whole target file.** All three Site A anchors occur exactly once in the merged file
   today, so the ordering assertion is correct — but `head -1` makes a second occurrence silently
   mis-anchor rather than fail, and the merged file is under concurrent edit. A uniqueness guard
   converts that silent hazard into a loud one. (Phase 4)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided for this task; ROADMAP.md was not consulted and is not modified.

### Ordering Contract (batch Contract 5)

This plan is sequenced **after** the H4-gate-port task, which lands the `researched`-state
adversarial-verification gate (H4) into `skill-orchestrate/SKILL.md`'s `hard_mode` branch. As of
planning, that gate is confirmed **not yet migrated** — the merged file's own residue note states
"Not migrated: the `researched`-state adversarial verification gate (H4)".

**Does the retargeted suite cover H4? No.** None of the seven files assert anything about the H4
gate or an `adversarial_verified` field. The one near-miss is `lint-contract-compliance.sh` Check
D's `adversarial_triggers` field, which is an H6/H5 churn-state counter — a different mechanism
that happens to share a word stem. This retarget therefore neither gains nor loses H4 coverage,
and adding H4 coverage is explicitly out of scope (see Non-Goals).

Sequencing after the H4 port is still binding for a different reason: that task edits the same
merged file these fixtures anchor into, so pinning anchors before it lands risks re-work.
Phase 1 verifies the H4 port has landed before any retarget edit is made.

## Goals & Non-Goals

**Goals**:
- All seven files target `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` only;
  zero remaining references to `skill-orchestrate-hard/SKILL.md` in the seven.
- Each file still exercises the same underlying mechanism it did before (retarget, not
  reinterpretation of intent).
- Where a mechanism is `hard_mode`-gated in the merged file, the fixture sets `hard_mode=true`
  explicitly rather than relying on the old implicit "the whole file is the hard engine".
- The two comparison-premise files are converted to single-file presence/correctness checks with
  no loss of the fields or behaviours they previously covered.
- Every anchor is a sentinel comment, heading text, or verbatim surrounding string — never a bare
  line number, and never a bare substring that also matches prose.
- A per-file mutation check demonstrates each retargeted file still catches its guarded bug.

**Non-Goals**:
- Deleting `skill-orchestrate-hard/SKILL.md`. It stays on disk; deletion is a separate dependent
  task. All seven files must pass both before and after that deletion.
- Retargeting Sites B and C of `test-resume-scan-nonconformance.sh`
  (`skill-implementer-hard/SKILL.md`, `skill-lean-implementation-hard/SKILL.md`). Those files are
  not part of this merge and stay untouched.
- Adding new coverage for the H4 adversarial-verification gate.
- Modifying `skill-orchestrate/SKILL.md` or any other file outside `scripts/tests/**` and
  `scripts/lint/**`. Mutation checks mutate the merged file only temporarily and revert.
- Any edit under `.claude/**` (batch Contract 7).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Concurrent sibling edits to `skill-orchestrate/SKILL.md` drift an anchor mid-implementation | H | H | Phase 1 re-verifies every anchor by search and records its uniqueness count; Phase 8 re-runs the full suite last, after all sibling work in the batch has landed. No line numbers are used as anchors. |
| A file is treated as "mechanical" and its behavioural fix is skipped (5 of 7 genuinely are mechanical, which normalizes the assumption) | H | M | The three non-mechanical fixes each get a dedicated phase (5, 6, 7) and a named assertion in Testing & Validation. Phase 2's mechanical trio explicitly excludes them. |
| The reader-parity rewrite quietly drops `skeleton` or `sorry_inventory` coverage, since their extraction patterns change rather than just their target | H | M | Phase 7's mutation check corrupts each field's filter individually and requires the test to fail naming that specific field — there is no cross-engine fallback signal left to mask a dropped check. |
| A bare-substring `grep -c` assertion silently matches prose in the 4,118-line merged file (the staleness marker-count defect) | M | M | Phase 3 converts marker counting to the full sentinel comment form; Phase 1 records begin/end counts for all four sentinels under both the bare and full form so the difference is visible before edits. |
| `test-handoff-dispatch-identity.sh`'s extracted region turns out to branch on `hard_mode` internally, making a single-fixture run insufficient | M | L | Phase 6 checks the extracted region for `hard_mode` reads before deciding between a one-fixture and two-fixture run, rather than assuming. |
| Mutation checks are performed by editing the merged file and a revert is forgotten, leaving the engine corrupted | H | L | Phase 8 records `git status --short` before and after each mutation and requires a clean tree between checks; mutations are made one at a time, never batched. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3, 4, 5, 6 | 1 |
| 3 | 7 | 6 |
| 4 | 8 | 2, 3, 4, 5, 7 |

Phases within the same wave can execute in parallel. Phases 2-6 each own a disjoint set of test
files, so parallel execution creates no write conflict; all of them only *read*
`skill-orchestrate/SKILL.md`.

---

### Phase 1: Anchor re-verification and baseline capture [COMPLETED]

- **Goal:** Confirm the H4 port has landed, re-locate every anchor by search in the current merged
  file, and record a baseline of which of the seven files pass today — so a Phase 8 failure can be
  attributed to the retarget rather than to pre-existing breakage.
- **Tasks:**
  - [x] Confirm the H4 `researched`-state adversarial-verification gate is present in
    `skill-orchestrate/SKILL.md`'s `hard_mode` branch and the file's residue note no longer lists
    it as "Not migrated". If it is still absent, stop and report — the ordering contract is unmet.
    *(completed: line 106 reads "H4 adversarial-verification gate — now ported."; no "Not
    migrated" residue note found)*
  - [x] For each of the four sentinels (`budget-continuation-override`, `loop-guard-staleness`,
    `dispatch-seq-gate`, `resume-scan-conformance-gate`) record two counts: the bare
    `<name>:begin` / `<name>:end` string count, and the full `# --- <name>:begin ---` /
    `# --- <name>:end ---` comment-form count. Note every name where the two differ.
    *(completed: loop-guard-staleness diverges, bare_begin=2 vs full_begin=1; the other three
    agree at 1/1)*
  - [x] Confirm the Stage 5 reader anchor comment (``not bare `.status`) so a handoff with a
    missing``) occurs exactly once. *(completed: line 2370, occurs once)*
  - [x] Confirm each Site A anchor of `test-resume-scan-nonconformance.sh`
    (`phase_scan_inconclusive" = "true"`, `elif [ -n "$next_phase" ]`,
    `elif [ "$last_skeleton" = "true" ]`) occurs exactly once; record the counts.
    *(completed: all three occur exactly once)*
  - [x] Confirm `command-route-agent.sh` call sites and note which fall inside the base
    dispatch-construction branch versus the `hard_mode`-gated per-phase-dispatch (H1) branch.
    *(completed: 5 occurrences total (lines 149, 159, 161, 163, 4505); 159/161/163 are the base
    dispatch-construction call sites — Phase 7 re-derives the H1 hard-branch site(s) directly when
    rewriting Assert 3)*
  - [x] Locate the merged file's `last_skeleton=` read, the `follow_up_tasks=`/`follow_up_count=`
    derivation from `.sorry_inventory[]?.follow_up_task`, and the `blocker_target=` /
    `verbatim_goal=` reads; record each one's exact assignment form. *(completed: last_skeleton=
    at 1694/1698; follow_up_tasks=/follow_up_count= at 1881-1882; blocker_target= at 2652,
    verbatim_goal= at 2671)*
  - [x] Run all seven files as-is and record pass/fail per file as the baseline. *(completed: all
    seven pass — budget-override 36/0, staleness 28/0, resume-scan 39/0, dispatch-identity 22/0,
    routing-resolution 19/0, reader-parity 19/0, lint-contract-compliance 24/0/0)*
- **Timing:** 0.5 hours
- **Depends on:** none
- **Verification Tier:** local
- **Scope Hypothesis:** Planning verified — in the merged file as of writing — that the bare and
  full sentinel forms diverge for `loop-guard-staleness` only (bare begin=2, full begin=1) and
  agree for the other three; that all Site A anchors and the Stage 5 reader anchor are unique; and
  that `command-route-agent.sh` occurs 5 times. Every one of these is a hypothesis about a file
  under concurrent edit, not a fact: re-derive all of them by search in this phase and drive the
  later phases from the re-derived values, not from the numbers written here.
- **Files to modify:**
  - None. This phase produces recorded findings consumed by Phases 2-7.
- **Verification:**
  - A recorded anchor table naming, for every anchor used downstream, its search string and its
    occurrence count in the current merged file.
  - A recorded baseline pass/fail line per file.

---

### Phase 2: Retarget `lint-contract-compliance.sh` (Checks C and D) [COMPLETED]

- **Goal:** Point both hard-engine references in the lint script at the merged engine, so the
  script survives the later deletion of `skill-orchestrate-hard/SKILL.md`.
- **Tasks:**
  - [x] In Check D's `check_d_convergence_policing`, change `skill_file` from
    `$CORE_ROOT/skills/skill-orchestrate-hard/SKILL.md` to
    `$CORE_ROOT/skills/skill-orchestrate/SKILL.md`. *(completed)*
  - [x] In Check C's tail block, change `orchestrate_skill` to the same merged path and update its
    pass/fail message strings. *(completed)*
  - [x] Update all `log_pass`/`log_fail`/`log_info` message strings and the section header comment
    for both checks to say `skill-orchestrate` rather than `skill-orchestrate-hard`, including the
    check-name line printed in the usage/summary block near the top of the file. *(completed)*
  - [x] Confirm the three convergence fields (`total_churn`, `target_churn`,
    `adversarial_triggers`) are all found in the merged file by the unchanged `grep -qF` logic.
    *(completed: all three PASS)*
  - [x] Confirm no `skill-orchestrate-hard` string remains anywhere in the file. *(completed:
    reworded one historical comment that named the string literally; grep -c now returns 0)*
- **Timing:** 0.5 hours
- **Depends on:** 1
- **Verification Tier:** local
- **Scope Hypothesis:** This phase asserts exactly two hard-engine reference sites in this file
  (Check C's existence assertion and Check D's `skill_file`), plus their message strings. Confirm
  by grepping the whole file for `skill-orchestrate-hard` before editing and again after; the
  after-count must be zero. If a third site appears, retarget it in this phase rather than
  deferring.
- **Files to modify:**
  - `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh` - retarget Check C's
    existence assertion and Check D's `skill_file`; update message strings.
- **Verification:**
  - The script runs and Checks C and D pass against the merged engine.
  - `grep -c skill-orchestrate-hard` on the file returns 0.

---

### Phase 3: Retarget `test-loop-guard-staleness.sh` [COMPLETED]

- **Goal:** Point the single-engine staleness test at the merged file, make its `hard_mode=true`
  fixture requirement explicit, and fix the marker-count assertion that a bare path swap would
  break.
- **Tasks:**
  - [x] Change `SKILL_FILE` to `skill-orchestrate/SKILL.md`. *(completed)*
  - [x] Change the `begin_count`/`end_count` assertions to count the full sentinel comment form
    (`# --- loop-guard-staleness:begin ---` / `# --- loop-guard-staleness:end ---`) with a fixed-
    string grep, so a prose mention of the sentinel name elsewhere in the merged file cannot
    inflate the count. Keep the "exactly one" expectation. *(completed)*
  - [x] Leave `BEGIN_MARKER`/`END_MARKER` as-is for `extract_region`'s awk range if the bare form
    still selects the correct region; if the prose mention precedes the real sentinel and would
    start the range early, switch `extract_region` to the full comment form too. *(completed:
    verified the prose mention at line 94 precedes the real sentinel at line 224, so
    `extract_region` was switched to the full comment form via `index($0, b/e)`)*
  - [x] Set `hard_mode=true` explicitly in the fixture environment that runs the extracted region.
    This was previously implicit because the whole target file was the hard engine. *(completed:
    `run_region()` now binds `hard_mode="true"` in its subshell)*
  - [x] Add an assertion that the fixture's `hard_mode` is `true`, so a future edit that drops the
    export fails loudly instead of silently skipping the whole gated detector region. *(completed:
    new assertion after Case 1 checks `result_hard_mode`; mutation-verified to fail loudly when
    the binding is removed)*
  - [x] Update the file's header comment to name Stage 2 of the merged engine. *(completed)*
- **Timing:** 0.75 hours
- **Depends on:** 1
- **Verification Tier:** local
- **Files to modify:**
  - `agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh` - retarget
    `SKILL_FILE`; harden marker counting; make `hard_mode=true` explicit and asserted.
- **Verification:**
  - The test passes against the merged engine, including both marker-count assertions.
  - Temporarily unsetting `hard_mode` in the fixture makes the new guard assertion fail rather
    than producing a silently-skipped detector region.

---

### Phase 4: Retarget `test-resume-scan-nonconformance.sh` Site A [NOT STARTED]

- **Goal:** Move Site A to the merged engine, relabel it, and convert its silent `head -1`
  mis-anchoring hazard into a loud failure.
- **Tasks:**
  - [ ] Change `SITE_A_FILE` to `skill-orchestrate/SKILL.md`. Leave `SITE_B_FILE`,
    `SITE_C_FILE`, and `SITE_D_FILE` untouched.
  - [ ] Update the label strings to "Site A (skill-orchestrate)" in both the extraction-failure
    message and the `SITE_LABEL` associative array, and in the file's header comment.
  - [ ] For each of the three Site A branch-order anchors, assert the grep matches exactly one line
    before taking `head -1`; fail with the anchor name and the observed count if not. This is the
    guard against a second occurrence appearing in the merged file and silently shifting the
    ordering assertion onto the wrong branch.
  - [ ] Confirm the `phase-heading-patterns.sh` library source line still sits immediately before
    the `resume-scan-conformance-gate:begin` marker at the new site, so the header comment's
    "library sourcing is deliberately outside the extracted region" note stays accurate. Correct
    the note if it does not.
  - [ ] Confirm the cross-site consistency assertions between Sites A, B, and C still pass.
- **Timing:** 0.75 hours
- **Depends on:** 1
- **Verification Tier:** local
- **Scope Hypothesis:** This phase assumes exactly three Site A line-derivation anchors and one
  Site A region extraction. Confirm by grepping the file for `SITE_A_FILE` and enumerating every
  use before editing; retarget each occurrence found, not only the three named here.
- **Files to modify:**
  - `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh` - retarget
    `SITE_A_FILE`, relabel, add per-anchor uniqueness guards.
- **Verification:**
  - The test passes with Site A on the merged engine and Sites B/C unchanged.
  - Injecting a duplicate of one Site A anchor into a scratch copy makes the new uniqueness guard
    fail by name.

---

### Phase 5: Retarget `test-loop-guard-budget-override.sh`, including the Case 4 correctness fix [NOT STARTED]

- **Goal:** Collapse the dual-file extraction to a single region run under both `hard_mode` values,
  and correct Case 4's `guard_session_id` expectation, which is now wrong against the merged
  file's correct behaviour.
- **Tasks:**
  - [ ] Replace `BASE_SKILL`/`HARD_SKILL` with a single target variable pointing at
    `skill-orchestrate/SKILL.md`, and update the file-existence preflight loop accordingly.
  - [ ] Extract one region using the `budget-continuation-override` begin marker plus the existing
    base resume-echo anchor (the `...(infra failures` line). Drop the hard resume-echo anchor:
    its exact single-line text no longer identifies a distinct region in this code path. Do not
    substitute the similarly-worded "lost init race" line, which is a different branch.
  - [ ] Replace the `for f in "$BASE_SKILL" "$HARD_SKILL"` iteration with an iteration over the two
    `hard_mode` values (`false`, `true`) injected into the `run_region` subshell environment
    against the one extracted region.
  - [ ] **Case 4 correctness fix:** remove the `engine_label == "base"` gate on the
    `guard_session_id` mismatch INFO-log assertion. In the merged file that check is unconditional,
    shared code. Assert the INFO log appears in **both** the `hard_mode=false` and `hard_mode=true`
    runs. Replace the stale in-file comment explaining the old "the hard engine's resume-read block
    has no `guard_session_id` check" rationale with one describing the current unconditional
    behaviour.
  - [ ] Collapse the two Stage 7 `MAX_CYCLES` / `--continue-budget` message checks into a single
    check against the merged file, and update its pass/fail strings.
  - [ ] Confirm the region still ends where the synthetic-`fi` append technique expects — the
    merged file's hard-only burnout echo is deliberately written as a self-closed `if` block so
    this technique keeps working. Do not restructure the extraction to depend on that block's
    internal shape.
- **Timing:** 1 hour
- **Depends on:** 1
- **Verification Tier:** local
- **Files to modify:**
  - `agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh` - single-file
    extraction, dual-`hard_mode` run, Case 4 assertion fix, Stage 7 check collapse.
- **Verification:**
  - All cases pass under both `hard_mode` values against the merged engine.
  - Case 4 now asserts the INFO log in both runs; the assertion is not skipped for either.
  - The `hard_mode=false` run produces no burnout line and the `hard_mode=true` run does.

---

### Phase 6: Retarget `test-handoff-dispatch-identity.sh` [NOT STARTED]

- **Goal:** Collapse the dual-file extract-and-diff to a single-file extraction, converting
  "these two copies agree" into "this one region behaves correctly", without weakening what the
  test detects.
- **Tasks:**
  - [ ] Replace `BASE_SKILL`/`HARD_SKILL` with a single merged-engine target and update the
    existence preflight loop and the `for pair in "base:..." "hard:..."` iteration.
  - [ ] Inspect the extracted combined staleness/`dispatch_seq` region for any read of
    `$hard_mode` or a `hard_mode`-derived variable. If none exists, run the region once. If any
    exists, run it under both `hard_mode=true` and `hard_mode=false`. Record which branch was
    taken and why in a comment — the research pass did not fully verify this and it must not be
    assumed either way.
  - [ ] Confirm the `append_detected_defect` stub-by-name mechanism still binds: the merged file
    keeps that helper as a locally-named function specifically so this test's stub-and-`eval`
    technique works. Do not rename or inline it in the test.
  - [ ] Update the header comment, which currently describes the gate as living in the hard
    engine's Stage 5, to describe the merged engine's Stage 5 and to note the gate is
    unconditional shared code rather than `hard_mode`-gated.
  - [ ] Confirm no `skill-orchestrate-hard` string remains in the file.
- **Timing:** 0.75 hours
- **Depends on:** 1
- **Verification Tier:** local
- **Files to modify:**
  - `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh` - single-file
    extraction; fixture-count decision recorded; header comment corrected.
- **Verification:**
  - The test passes against the merged engine.
  - A recorded statement of whether the extracted region reads `hard_mode`, with the evidence that
    settled it, and a fixture count consistent with that answer.

---

### Phase 7: Rewrite `test-routing-resolution.sh` Assert 3 and `test-handoff-reader-parity.sh` [NOT STARTED]

- **Goal:** Convert the two files whose "compare two engine files" premise no longer holds into
  single-file presence/correctness checks, preserving — and in one case strengthening — what each
  originally guarded.
- **Tasks:**
  - **`test-routing-resolution.sh` (Assert 3 only; Asserts 1, 2, and 4 are manifest-driven and must
    not be touched):**
    - [ ] Remove `ORCH_HARD_SKILL` and drop it from the file-existence preflight loop.
    - [ ] Replace the `orch_calls` versus `orch_hard_calls` count-and-compare with a branch-aware
      intra-file check: assert `command-route-agent.sh` call sites exist **both** inside the base
      dispatch-construction branch **and** inside the `hard_mode`-gated per-phase-dispatch (H1)
      branch, anchored on the H1 branch's own heading text. A flat whole-file count would pass even
      if one mode's dispatch sites were deleted entirely — that is precisely the regression the old
      cross-engine comparison used to catch, and a flat count would lose it.
    - [ ] Reduce the `case "$TASK_TYPE"` / `sed s/^skill-` anti-pattern grep to the single merged
      file.
    - [ ] Update the file's header comment, which describes Assert 3 as an engine-parity check, to
      describe it as an intra-file branch-coverage check.
  - **`test-handoff-reader-parity.sh` (the largest piece):**
    - [ ] Collapse `resolve_candidate` usage to the single merged engine; drop `HARD_SKILL` and its
      resolution-failure branch, and update the trailing "Base engine resolved to / Hard engine
      resolved to" info lines.
    - [ ] Convert the `SHARED_FIELDS` loop from extract-twice-and-compare to extract-once: assert
      the filter is present and non-empty, then assert it produces the expected value against the
      shared fixture. Keep the fixture and the `validate-handoff.sh` check unchanged.
    - [ ] Apply the same conversion to the multi-line `continuation` dual-form-resolution block and
      to the `artifacts[0].{path,type,summary}` triplet.
    - [ ] Rewrite the `skeleton` extraction: the old `skeleton=$(echo "$handoff" | jq -r '...')`
      pattern no longer exists. The merged file reads it as a differently-named variable directly
      from the handoff file rather than from the already-loaded `$handoff` variable, and it lives
      in the Stage 4 `hard_mode`-gated per-phase-dispatch branch, not Stage 5. Update both the
      extraction regex and the "where it lives" framing in the comments.
    - [ ] Rewrite or retire the `sorry_inventory` assertion. The merged file no longer assigns a
      `sorry_inventory=` variable; it inlines `.sorry_inventory[]?.follow_up_task` into the
      follow-up-task derivation, and that code path is now unconditional rather than
      `hard_mode`-gated. Remove it from the "hard-only, not compared to base" bucket. Prefer a
      single-file presence check on the inlined filter over deletion; delete only if the field is
      demonstrably covered elsewhere, and say where.
    - [ ] Retarget the `blocker_target` and `verbatim_goal` extractions to the merged file. These
      survived unchanged — same variable names, same read form — so no pattern changes are needed.
      Correct their comment framing to name the Stage 5b `hard_mode`-gated churn-detection block.
    - [ ] **Remove the `dispatch_seq` gate base-versus-hard comparison block** (the sentinel-region
      extraction plus its `s/skill-orchestrate-hard/skill-orchestrate/g` normalization). With one
      engine it compares a file to itself and passes vacuously; the real coverage lives in
      `test-handoff-dispatch-identity.sh`. Leave a brief comment recording where that coverage now
      lives so the removal does not read as an accidental deletion.
    - [ ] Confirm no `skill-orchestrate-hard` string remains in either file.
- **Timing:** 2 hours
- **Depends on:** 6
- **Verification Tier:** local
- **Scope Hypothesis:** This phase asserts seven distinct field/block checks in
  `test-handoff-reader-parity.sh`: the `SHARED_FIELDS` set, the `continuation` block, the
  `artifacts[0].*` triplet, `skeleton`, `sorry_inventory`, the `blocker_target`/`verbatim_goal`
  pair, and the `dispatch_seq` gate block. Confirm the enumeration by reading the file end to end
  before editing; if an eighth check exists, convert it in this phase rather than leaving it
  comparing the merged file to itself.
- **Files to modify:**
  - `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh` - Assert 3 rewritten as
    a branch-aware intra-file check; `ORCH_HARD_SKILL` removed.
  - `agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh` - single-engine
    resolution; comparison checks converted to presence/correctness; `skeleton` and
    `sorry_inventory` extraction rewritten; vacuous `dispatch_seq` comparison removed.
- **Verification:**
  - Both files pass against the merged engine.
  - `test-handoff-reader-parity.sh` reports a pass line for every field it covered before, with
    `sorry_inventory` either still covered or its removal justified in a comment naming its new
    coverage site.
  - Deleting a `command-route-agent.sh` call from inside the H1 hard branch only makes Assert 3
    fail — confirming the strengthening is real and not just a reworded flat count.

---

### Phase 8: Full-suite run and per-file mutation checks [NOT STARTED]

- **Goal:** Demonstrate that no coverage was lost: the whole suite is green, and each retargeted
  file still fails when the specific bug it guards is reintroduced into the merged engine.
- **Tasks:**
  - [ ] Run the full test suite via `scripts/tests/run-all.sh` and compare against the Phase 1
    baseline. Any file that passed at baseline and fails now is a regression from this work and
    must be fixed, not annotated.
  - [ ] Run `lint-contract-compliance.sh` in full and confirm all checks pass.
  - [ ] Mutation check, `lint-contract-compliance.sh`: delete the `adversarial_triggers` field from
    the churn-init JSON literal in the merged engine; confirm Check D fails naming that field.
    Revert.
  - [ ] Mutation check, `test-loop-guard-staleness.sh`: run the retargeted test with `hard_mode`
    unset; confirm it fails loudly on the new fixture guard rather than silently skipping the
    detector region. No engine mutation needed.
  - [ ] Mutation check, `test-resume-scan-nonconformance.sh`: reorder two lines inside Site A's
    extracted region in the merged engine, breaking the shared ordering contract; confirm the
    cross-site consistency assertion against Sites B and C fails. Revert.
  - [ ] Mutation check, `test-handoff-dispatch-identity.sh`: mismatch the minted `dispatch_seq`
    between mint-time and read-time in the fixture; confirm `DISPATCH_SEQ MISMATCH` is still
    detected. Separately rename `append_detected_defect` in a scratch copy of the engine and
    confirm the stub-by-name mechanism breaks loudly — proving the stub is still load-bearing.
    Revert.
  - [ ] Mutation check, `test-loop-guard-budget-override.sh`: delete the `guard_session_id`
    mismatch check from the merged engine; confirm the **fixed** Case 4 fails for both `hard_mode`
    runs, not just one. Separately remove the `if` guard around the hard-only burnout echo and
    confirm the `hard_mode=false` run detects the now-unconditional line. Revert both.
  - [ ] Mutation check, `test-routing-resolution.sh`: delete one `command-route-agent.sh` call from
    inside the H1 hard branch only, leaving base-branch calls intact; confirm the branch-aware
    Assert 3 fails. Revert.
  - [ ] Mutation check, `test-handoff-reader-parity.sh`: for each field/block check the file still
    carries, corrupt that field's jq filter in the merged engine one at a time and confirm the test
    fails naming that specific field. There is no cross-engine fallback signal left, so each check
    must independently detect its own field's breakage. Revert after each.
  - [ ] Confirm `git status --short` is clean of engine-file changes after every mutation, and once
    more at the end of the phase.
  - [ ] Confirm zero `skill-orchestrate-hard` references remain across all seven files.
  - [ ] Confirm no task-number references were introduced into any of the seven files
    (deliverables outside `specs/**`).
- **Timing:** 1.75 hours
- **Depends on:** 2, 3, 4, 5, 7
- **Verification Tier:** full
- **Scope Hypothesis:** This phase asserts one mutation check per retargeted file, plus one per
  surviving field check in `test-handoff-reader-parity.sh` (provisionally seven, pending Phase 7's
  final field set). Derive the reader-parity mutation count from the file as Phase 7 leaves it, not
  from this estimate.
- **Files to modify:**
  - None permanently. `skill-orchestrate/SKILL.md` is mutated and reverted, one mutation at a time.
- **Verification:**
  - Full suite green, with a pass/fail line per file compared against the Phase 1 baseline.
  - Every mutation check produces a *named* failure in the expected file, and a clean tree after
    revert.

---

## Testing & Validation

- [ ] `scripts/tests/run-all.sh` passes, with no file regressing against the Phase 1 baseline.
- [ ] `scripts/lint/lint-contract-compliance.sh` passes end to end, Checks C and D included.
- [ ] `grep -rl 'skill-orchestrate-hard' ` across the seven files returns nothing.
- [ ] All seven files pass both with `skill-orchestrate-hard/SKILL.md` still on disk and with it
  removed (simulate by temporarily renaming it, then restoring) — this is the actual acceptance
  condition for the dependent deletion task.
- [ ] `test-loop-guard-budget-override.sh` Case 4 asserts the `guard_session_id` INFO log in both
  the `hard_mode=false` and `hard_mode=true` runs.
- [ ] `test-routing-resolution.sh` Assert 3 fails when a `command-route-agent.sh` call is removed
  from the H1 hard branch alone.
- [ ] `test-handoff-reader-parity.sh` covers every field it covered before, or documents in a
  comment where a dropped field's coverage now lives.
- [ ] `test-loop-guard-staleness.sh` marker-count assertions pass against the merged file and are
  immune to prose mentions of the sentinel name.
- [ ] No task-number references introduced into any file outside `specs/**`.
- [ ] No file under `.claude/**` was modified.

## Artifacts & Outputs

- `specs/120_retarget_hard_mode_tests_to_engine_branch/plans/01_retarget-hard-mode-tests.md` (this file)
- `specs/120_retarget_hard_mode_tests_to_engine_branch/summaries/01_retarget-hard-mode-tests-summary.md`
- Modified: `agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-routing-resolution.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-handoff-reader-parity.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-loop-guard-staleness.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-handoff-dispatch-identity.sh`
- Modified: `agent-system/extensions/core/scripts/tests/test-resume-scan-nonconformance.sh`
- Modified: `agent-system/extensions/core/scripts/lint/lint-contract-compliance.sh`

## Rollback/Contingency

Each phase edits a disjoint set of files and commits separately, so a single phase can be reverted
with `git revert` of its commit without disturbing the others. The merged engine
`skill-orchestrate/SKILL.md` is never permanently modified — Phase 8's mutations are reverted
individually and the tree is confirmed clean between them; if a revert is missed, restore the file
from HEAD.

If the H4-gate-port task has not landed when Phase 1 runs, stop before making any edit and report
the unmet ordering contract rather than retargeting against a non-final hard-mode surface.

If a sibling task's concurrent edit invalidates an anchor mid-implementation, re-run Phase 1's
anchor re-verification for the affected file and adjust that file's phase only; the other phases
are independent and need not be redone.
