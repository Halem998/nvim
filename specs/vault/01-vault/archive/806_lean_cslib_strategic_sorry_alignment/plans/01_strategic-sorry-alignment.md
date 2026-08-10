# Implementation Plan: Task #806

- **Task**: 806 - Align lean/cslib hard-mode contracts with 778 strategic-sorry policy
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: task 778 (COMPLETED - landed the core policy this task aligns to)
- **Research Inputs**: specs/806_lean_cslib_strategic_sorry_alignment/reports/01_lean-cslib-sorry-alignment.md
- **Artifacts**: plans/01_strategic-sorry-alignment.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Task 778 relaxed the CORE `--hard` zero-debt policy to permit documented **strategic sorries**
forming a skeleton, gated by a domain-agnostic 5-condition acceptance test, and standardized a
7-field `sorry_inventory` schema `{file, line, statement, strategic, assumption, why_deferred,
follow_up_task}`. The lean/cslib hard-mode overrides still forbid main-target sorries
UNCONDITIONALLY, directly contradicting the new core policy. This plan reconciles the lean/cslib
hard-mode contracts across the **6 anchor points in 3 files** the research identified (not the
single override file named in the task): it replaces each categorical main-target-sorry ban with
the 5-condition strategic-sorry test specialized for Lean4 (where `sorry` is the canonical
placeholder), aligns field naming to `follow_up_task`, adds Lean4 domain guidance (sorry must
typecheck; track via `#print axioms`/`sorryAx` and `declaration uses 'sorry'`), and flags the
stale cross-repo `~/Projects/cslib` copy for manual re-sync without editing it. Standard-mode
lean/cslib agents are explicitly untouched. Definition of done: all 6 anchor points corrected, no
residual `next_dispatch` occurrences, schema parity with core `wrap-up.md`, and a cross-repo
re-sync NOTE plus the Context-References open-question decision recorded in the implementation
summary.

### Research Integration

The research report (`reports/01_lean-cslib-sorry-alignment.md`) supplies exact line anchors,
verbatim current text, and recommended replacement wording for every anchor point. Key integrated
findings:
- The contradiction is restated (not merely @-referenced) inline in both agent `.md` files, so a
  complete fix touches 6 anchor points across 3 files, not just the override file.
- The `next_dispatch` -> `follow_up_task` rename is safe: `grep -rn "next_dispatch" .claude/`
  returns only 5 documentation occurrences (in the two target files), zero script dependencies
  (confirmed re-run during planning; note line 291 of the lean agent file is an additional
  `next_dispatch` field-description occurrence to include in the rename sweep).
- Core `anti-analysis.md` line 99 already sanctions lean overriding only the *proof-line-bar*, not
  a categorically stricter sorry ban - so the override adds Lean4 guidance without re-banning
  deliberate skeleton sorries.
- The cslib Context-References path ambiguity (core vs. lean override) is a pre-existing gap; the
  research recommends deciding-and-documenting rather than silently fixing.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this task (meta task; no roadmap_path provided).

## Goals & Non-Goals

**Goals**:
- Replace the unconditional main-target-sorry prohibition with the core 5-condition
  strategic-sorry test, specialized for Lean4, at all 6 research-identified anchor points.
- Add Lean4 domain guidance: `sorry` is the canonical build-green placeholder; track real sorries
  via `#print axioms <decl>` (showing `sorryAx`) and `declaration uses 'sorry'` warnings.
- Rename `next_dispatch` -> `follow_up_task` and extend `sorry_inventory` entries to the canonical
  7-field schema `{file, line, statement, strategic, assumption, why_deferred, follow_up_task}`
  everywhere in the three files; add `skeleton` to the handoff JSON examples.
- Preserve the lean override's still-valid leaf-sorry criteria and its (legitimate)
  proof-line-bar specialization.
- Flag the stale `~/Projects/cslib` flattened copy for manual re-sync via a NOTE in the
  implementation summary; do NOT edit that repo.
- Record an explicit decision on the cslib Context-References open question.

**Non-Goals**:
- No changes to standard-mode agents (`lean-implementation-agent.md`,
  `cslib-implementation-agent.md`) - standard-mode zero-debt bar is unchanged.
- No edits to `~/Projects/cslib/.claude/` (flag only).
- No change to the lean override's proof-line-bar bound - only the sorry policy is relaxed.
- No modification of core `anti-analysis.md` / `wrap-up.md` (already 778-landed; used as the
  alignment target, read-only).
- Do NOT silently change cslib's Context-References path (evaluated as an explicit plan decision
  in Phase 4, defaulting to no-change + follow-up recommendation).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Editing only the override file leaves the contradiction live in the two agent files (each restates policy inline; lean agent is self-contained/non-@-referencing) | H | M | Plan mandates all 6 anchor points across 3 files (Phases 1-3); Phase 4 greps to confirm no residual categorical ban / `next_dispatch` |
| `next_dispatch` -> `follow_up_task` rename silently breaks a consuming script | M | L | Research + planning re-run of `grep -rn "next_dispatch" .claude/scripts/` returns nothing; Phase 4 re-verifies zero residual occurrences repo-wide |
| Scope creep into standard-mode agents | M | L | Non-Goals explicitly exclude them; Phase 4 verifies only the 3 target files changed |
| New Lean4 wording drifts from core's 5-condition semantics | M | M | Phase 1 mirrors core `anti-analysis.md` lines 59-83 field-for-field; Phases 2-3 reference Phase 1's wording for consistency |
| Silently "fixing" the cslib Context-References path alters H2 proof-line-bar behavior beyond sorry policy | M | M | Phase 4 records it as an explicit no-change decision + follow-up recommendation, not an in-scope edit |
| Cross-repo staleness forgotten, leaving `~/Projects/cslib` contradictory after 806 lands | M | M | Phase 4 requires a visible re-sync NOTE in the implementation summary listing the files to re-copy |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel. Phase 1 establishes the canonical Lean4
strategic-sorry wording that Phases 2 and 3 reference for consistency.

### Phase 1: Update the lean override contract (anti-analysis.md) [COMPLETED]

**Goal**: Replace the categorical leaf-only ban in the lean override with a Lean4-specialized
5-condition strategic-sorry subsection, and align the H9 sorry_inventory field list to core's
7-field schema. This file's new wording becomes the canonical reference for Phases 2-3.

**File**: `.claude/extensions/lean/context/contracts/anti-analysis.md` (85 lines)

**Tasks**:
- [x] In `## Sub-Sorry Policy for Leaf Sorries` (lines ~60-74): KEEP the leaf-sorry criteria
      (items 1-3, which are not in conflict with core - core's test governs only main-target-level
      placeholders). REMOVE the categorical ban line ~71
      (`**Non-leaf sorries (i.e., main-target sorries) are NEVER acceptable as final output.**`)
      and the "dispatch has failed to make progress"/escalation sentence at lines ~73-74.
      *(completed)*
- [x] Add a new subsection `### Strategic main-target sorries (Lean4 skeleton division points)`
      mirroring core `anti-analysis.md` lines 59-83, specialized for Lean4 per the research's
      recommended replacement wording (report Findings section 2, File 1). The five conditions:
      (1) deliberate division boundary NOT an abandoned/stuck proof; (2) tightly scoped to exactly
      one theorem/lemma/definition; (3) documented with assumption / why-deferred / owning
      follow-up task; (4) tracked in `sorry_inventory` with `strategic: true` and non-null
      `follow_up_task`; (5) build-green - `sorry` is Lean4's canonical placeholder, `lake build`
      (or scoped module build) must still succeed; track via `#print axioms <decl>` showing
      `sorryAx` and/or `declaration uses 'sorry'` warnings to confirm the sorry is real and located
      where documented. State that non-strategic main-target sorries remain forbidden and the
      Escalation Protocol applies instead. *(completed)*
- [x] In `## Interaction with H9 Sorry Inventory` (lines ~76-84), update item 2's field list from
      `{file, line, statement, assumption, why_deferred, next_dispatch}` to the canonical
      `{file, line, statement, strategic, assumption, why_deferred, follow_up_task}` (line ~82).
      *(completed)*
- [x] Do NOT alter the proof-line-bar / forbidden-conclusions content - only the sorry policy.
      *(completed: verified unchanged)*

**Timing**: 40 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/lean/context/contracts/anti-analysis.md` - relax leaf-only ban to
  5-condition strategic-sorry test; fix H9 field schema.

**Verification**:
- File no longer contains "NEVER acceptable as final output" for main-target sorries.
- New `### Strategic main-target sorries (Lean4 skeleton division points)` subsection present with
  all five conditions.
- `grep -n "next_dispatch" .claude/extensions/lean/context/contracts/anti-analysis.md` returns
  nothing.
- Field list reads `{file, line, statement, strategic, assumption, why_deferred, follow_up_task}`.

---

### Phase 2: Correct lean-implementation-hard-agent.md (5 anchor points) [COMPLETED]

**Goal**: Fix all five inline restatements of the categorical ban in the self-contained lean hard
agent file, and align its schema/field naming with Phase 1 and core `wrap-up.md`.

**File**: `.claude/extensions/lean/agents/lean-implementation-hard-agent.md` (463 lines)

**Tasks**:
- [x] **(a) Stage 5 handoff JSON example (lines ~258-280)**: add `"skeleton": false` to the
      example schema (with a note it may be `true` when a tracked strategic sorry remains); rename
      the `sorry_inventory` entry field `next_dispatch` -> `follow_up_task` (line ~273) and add
      `strategic` to the entry. Include the `next_dispatch` field-description occurrence at
      line ~291 in the rename. *(completed: also caught an additional next_dispatch occurrence
      in Stage 4 step C not named in the plan text)*
- [x] **(b) "Leaf sub-sorry vs. main-target sorry" (lines ~293-297)**: keep the leaf-sub-sorry
      guidance; add an explicit strategic-sorry branch - when all five core conditions hold, a
      main-target sorry goes in `sorry_inventory` with `strategic: true` and `follow_up_task`
      populated (NOT in `blockers`), and `status` may be `"implemented"` with `skeleton: true`.
      Remove the unconditional "set `status: partial` if any main-target sorries remain".
      *(completed)*
- [x] **(c) Stage 6 Final Verification item 1 (lines ~310-316)**: change
      "`sorry_count` (must be 0 for implemented status)" to: `sorry_count` must be 0 OR every
      remaining sorry is tracked in `sorry_inventory` with `strategic: true` and satisfies the
      five-condition test; otherwise `status` cannot be `"implemented"`. *(completed)*
- [x] **(d) "Zero-Debt Policy" section (lines ~394-402)**: add a new exception item for strategic
      main-target sorries (parallel to the existing leaf-sub-sorry exceptions), citing the
      five-condition test; rename `next_dispatch` -> `follow_up_task` at line ~402. Retain the
      section heading. *(completed)*
- [x] **(e) "MUST NOT" list item 4 (line ~456)**: extend the parenthetical to
      "(leaf sorries must be in inventory; main-target sorries only permitted as tracked strategic
      sorries meeting the five-condition test, with `skeleton: true`)". *(completed)*
- [x] Keep wording consistent with Phase 1's new override subsection. *(completed)*

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/lean/agents/lean-implementation-hard-agent.md` - 5 anchor points (a-e).

**Verification**:
- `grep -n "next_dispatch" .claude/extensions/lean/agents/lean-implementation-hard-agent.md`
  returns nothing.
- Handoff JSON example contains `"skeleton"` and the `sorry_inventory` entry contains `strategic`
  and `follow_up_task`.
- No remaining unconditional "set `status: partial` if any main-target sorries remain" or
  "must be 0 for implemented status" absolute gates.

---

### Phase 3: Correct cslib-implementation-hard-agent.md (2 anchor points) [COMPLETED]

**Goal**: Fix the two inline restatements in the cslib hard agent file so its sorry policy matches
the corrected lean file, keeping cslib and lean agents consistent.

**File**: `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` (357 lines)

**Tasks**:
- [x] **(a) Stage 5 handoff JSON + prose (lines ~260-275)**: extend the `sorry_inventory` prose to
      reference the core five-condition strategic-sorry test and the `skeleton` field, matching the
      corrected lean file's wording; make clear that a tracked strategic main-target sorry with
      `strategic: true` and `follow_up_task` is permissible with `skeleton: true`, not only
      `sorry_inventory: []`. Add `skeleton` to the handoff example. *(completed)*
- [x] **(b) "MUST NOT" list item 5 (line ~351)**: apply the same fix as lean file item (e) - add
      the strategic-sorry/skeleton exception to "Return implemented status if any sorry remains".
      *(completed)*
- [x] Do NOT touch the cslib Escalation Protocol section (lines ~321-329) - it governs `[BLOCKED]`
      phases, which is orthogonal to strategic skeleton sorries. *(completed: verified unchanged)*
- [x] Do NOT change the cslib Context-References path in this phase - that decision is handled in
      Phase 4. *(completed: deferred to Phase 4)*

**Timing**: 25 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md` - 2 anchor points (a-b).

**Verification**:
- MUST-NOT item 5 now carries the strategic-sorry/skeleton exception.
- `sorry_inventory` prose references the five-condition test and `skeleton`/`follow_up_task`.
- Escalation Protocol section unchanged.

---

### Phase 4: Consistency verification, cross-repo flag, and open-question decision [COMPLETED]

**Goal**: Verify schema/policy parity across all three edited files and core, record the cslib
Context-References decision, and flag the stale cross-repo copy for manual re-sync.

**Tasks**:
- [x] Run `grep -rn "next_dispatch" .claude/` and confirm zero occurrences remain (rename complete
      repo-wide). *(completed: zero occurrences)*
- [x] Run `grep -rn "NEVER acceptable" .claude/extensions/lean .claude/extensions/cslib` (and
      similar categorical phrasings) to confirm no residual unconditional main-target-sorry ban.
      *(completed: zero occurrences)*
- [x] Confirm every `sorry_inventory` field list in the three files matches core `wrap-up.md`'s
      canonical `{file, line, statement, strategic, assumption, why_deferred, follow_up_task}`
      (read core `wrap-up.md` lines ~42-51 read-only for the reference schema). *(completed: all
      four files - 3 edited + core wrap-up.md - use the identical 7-field schema)*
- [x] Confirm standard-mode agent files (`lean-implementation-agent.md`,
      `cslib-implementation-agent.md`) were NOT modified (`git status` shows only the 3 hard-mode
      files changed). *(completed: git status/diff confirms zero changes to standard-mode files)*
- [x] **Open-question DECISION (cslib Context References)**: Record the explicit decision in the
      implementation summary: do NOT change cslib-implementation-hard-agent.md's Context-References
      path (currently the CORE `@.claude/context/contracts/anti-analysis.md`) in task 806, because
      changing it to the lean override would also import the lean proof-line-bar / forbidden
      conclusions, altering H2 behavior beyond this task's sorry-policy scope. Recommend spawning a
      dedicated follow-up task to resolve the ambiguity deliberately. *(completed: recorded in
      summary)*
- [x] **Cross-repo re-sync NOTE**: Add a clearly-labeled `> **NOTE (downstream re-sync)**` block to
      the implementation summary instructing the user to manually re-copy the three corrected files
      (plus checking core `anti-analysis.md` and `wrap-up.md`, which are already flattened/stale in
      that repo) into `~/Projects/cslib/.claude/` after 806 lands. Do NOT edit `~/Projects/cslib`.
      *(completed: recorded in summary)*
- [x] Write the implementation summary capturing the 6 anchor points changed, the field rename, the
      open-question decision, and the cross-repo NOTE. *(completed)*

**Timing**: 30 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- `specs/806_lean_cslib_strategic_sorry_alignment/summaries/01_strategic-sorry-alignment-summary.md`
  (created lazily at implement time).

**Verification**:
- `grep -rn "next_dispatch" .claude/` -> empty.
- `git status` shows exactly the 3 hard-mode files edited (plus the summary artifact).
- Implementation summary contains both the cslib Context-References decision and the cross-repo
  re-sync NOTE.

## Testing & Validation

- [x] `grep -rn "next_dispatch" .claude/` returns no results. *(verified)*
- [x] Lean override `anti-analysis.md` contains the `### Strategic main-target sorries (Lean4
      skeleton division points)` subsection with all five conditions and no categorical
      "NEVER acceptable" main-target ban. *(verified)*
- [x] Both hard agent files include `skeleton` in handoff JSON examples and `strategic` +
      `follow_up_task` in `sorry_inventory` entries. *(verified)*
- [x] All three files' `sorry_inventory` field lists match core `wrap-up.md`'s 7-field schema.
      *(verified)*
- [x] `git diff --name-only` lists only the three hard-mode files (no standard-mode agent files).
      *(verified: cslib-implementation-hard-agent.md, lean-implementation-hard-agent.md,
      lean/context/contracts/anti-analysis.md only, among the target files)*
- [x] Implementation summary records the cslib Context-References open-question decision and the
      `~/Projects/cslib` re-sync NOTE. *(verified)*

## Artifacts & Outputs

- plans/01_strategic-sorry-alignment.md (this plan)
- Edited: `.claude/extensions/lean/context/contracts/anti-analysis.md`
- Edited: `.claude/extensions/lean/agents/lean-implementation-hard-agent.md`
- Edited: `.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md`
- summaries/01_strategic-sorry-alignment-summary.md (includes cross-repo re-sync NOTE and
  Context-References decision)

## Rollback/Contingency

All changes are markdown edits to three documentation files under version control. To revert:
`git checkout -- .claude/extensions/lean/context/contracts/anti-analysis.md
.claude/extensions/lean/agents/lean-implementation-hard-agent.md
.claude/extensions/cslib/agents/cslib-implementation-hard-agent.md`. No build, no runtime, no data
migration is involved; the cross-repo copy is untouched, so reverting here leaves both repos in
their pre-806 (mutually consistent-stale) state. If a partial edit is discovered, re-run the
affected phase - phases are independent per file (Phases 2 and 3) with Phase 1 as the shared
wording anchor.
