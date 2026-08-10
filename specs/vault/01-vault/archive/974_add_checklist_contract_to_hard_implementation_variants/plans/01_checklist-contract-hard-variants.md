# Implementation Plan: Task #974

- **Task**: 974 - Add plan-checklist mark-completed contract to the two hard-mode implementation agent variants
- **Status**: [COMPLETED]
- **Effort**: 1.0 hours
- **Dependencies**: Task 971 (COMPLETED) — establishes the canonical loosened matching wording
- **Research Inputs**: specs/974_add_checklist_contract_to_hard_implementation_variants/reports/01_checklist-contract-hard-variants.md
- **Artifacts**: plans/01_checklist-contract-hard-variants.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Both hard-mode implementation agents currently carry a single bare bullet — `- For each completed
checklist item: check off in plan file` — with no matching contract, no annotation vocabulary, and
no guidance on what to match against. This plan replaces that one-line placeholder in each file
with the full canonical `Check Off Completed Items in Plan File` contract established in
`general-implementation-agent.md` section `#### 4B-ii`, quoted verbatim. Both edits are purely
additive at the site of a one-line deletion; no hard-mode structure (H9 wrap-up, `sorry_inventory`,
territory contracts, Stage 5a marker repair, `.orchestrator-handoff.json` behavior) is touched.

### Research Integration

The research report supplied three load-bearing facts this plan builds on directly:

1. **Canonical block extracted and re-verified.** The block spans
   `agent-system/extensions/core/agents/general-implementation-agent.md` lines 183-217 (the body
   under the `#### 4B-ii.` heading at line 181). Re-confirmed byte-identical to the research
   quotation during planning.
2. **Insertion sites identified.** Core hard file line 174; cslib hard file line 211 — each the
   bare placeholder bullet, each immediately inside the `**B. Execute Steps**` bullet list, each
   well clear of Stage 5's wrap-up contract.
3. **Dash style resolved.** Both hard files already use U+2014 em-dashes in their own prose (core:
   18 instances, cslib: 4). The canonical block, which carries 4 em-dashes of its own, therefore
pastes in unchanged — no
   dash-style deviation is needed in either file, and none is permitted.

Additional planning-time verification (baselines the implementer will re-check as post-conditions):
both files currently return `0` for `- [x]` and `0` for `Task {P}.{N}`.

### Where the Canonical Block Belongs in Each File — the Hard-Mode Dimension

The base agent's *position* does not transfer unchanged, because the two hard files do not share
the base agent's heading structure. The base agent renders its lettered steps as `####` headings
(`#### 4B-ii. ...`, `#### 4B-iii. ...`); both hard files render theirs as bold labels
(`**A. Mark Phase In Progress**`, `**B. Execute Steps**`, `**C. Verify Phase Completion**`,
`**D. Mark Phase Complete**`). The insertion must therefore use a **bold label**,
`**B-ii. Check Off Completed Items in Plan File**`, sited as a sibling of the existing bold
lettered steps and immediately before each file's own `**C. Verify Phase Completion**` line — not
a `####` heading, which would break the surrounding convention.

Per-file specifics:

- **`general-implementation-hard-agent.md`**: its `**B. Execute Steps**` header reads "following
  the same pattern as base agent, plus:", so base-agent 4B-ii is arguably inherited by reference
  already. That inheritance is implicit and is contradicted in practice by the bare placeholder
  bullet, which states a weaker instruction in the same list. Making the contract explicit
  resolves the contradiction rather than duplicating a working inheritance. The two other B
  bullets (8-tool-call anti-analysis check; track-on-write `files_touched`) stay in place
  unchanged, as does `**D-ii. Post-Phase Self-Review**`, which cross-references the annotation
  format.
- **`cslib-implementation-hard-agent.md`**: its `**B. Execute Steps**` header reads "plus hard-mode
  additions:" and the file's "same as base" references point at *cslib* siblings
  (`base hard agent` at Stage 4.5, `base cslib-implementation-agent` at Stage 5). Its non-hard
  cslib sibling still carries the brittle `**Task {P}.{N}**:` prefix idiom, so inheritance-by-
  reference here would propagate the exact bug being eliminated. Explicit inclusion is required,
  not merely preferable. The two Lean-specific B bullets (`lean_goal` before/after each tactic;
  `lean_multi_attempt` before edits) sit *after* the placeholder bullet and must remain in the B
  list in their existing order.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` supplied in the delegation context; no roadmap phases required.

## Goals & Non-Goals

**Goals**:
- Replace the bare placeholder bullet in each of the two hard-mode agent files with the full
  canonical `Check Off Completed Items in Plan File` contract, quoted verbatim.
- Preserve each file's existing bold lettered-step structure and em-dash prose convention.
- Leave every hard-mode contract (H9 wrap-up, `sorry_inventory`, territory, Stage 5a, handoff)
  byte-unchanged.

**Non-Goals**:
- Fixing the brittle `**Task {P}.{N}**:` prefix idiom in `web-implementation-agent.md` or
  `neovim-implementation-agent.md` (see Recommended Follow-On Task below).
- Fixing the non-hard `cslib-implementation-agent.md` sibling (separate, already-named task).
- Touching the four `.orchestrator-handoff.json` references in the cslib hard file.
- Any write under `.claude/**` — that tree is a gitignored, disposable deploy artifact.
- Unifying dash style across files, or any other punctuation churn.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer paraphrases the canonical block instead of quoting it | H | M | The block's own first sentence says "quote this block verbatim; do not paraphrase it". Phase 3 diffs the inserted text against the canonical source to prove byte-equality. |
| Implementer renumbers the A/B/C/D lettered steps to accommodate a "B-ii" step | M | L | `general-implementation-agent.md` already uses `4B-ii`/`4B-iii` as sibling-step names without renumbering; reuse that proven naming. Phase 3 greps for the four bold lettered labels in each file. |
| Edit lands in `.claude/**` instead of the source store | H | L | Both phases name absolute `agent-system/extensions/**` paths. Phase 3 asserts `git diff --stat` shows exactly the two source-store paths. |
| Dash churn while pasting (em-dash silently normalized to ASCII `--`) | L | M | Phase 3 asserts em-dash counts rose by exactly the canonical block's 3 em-dashes per file and that no ASCII `--` appears in annotation position. |
| Nearby Stage 5 / `sorry_inventory` content perturbed | H | L | Insertion point is inside Stage 4's B-list, far above Stage 5 in both files. Phase 3 asserts the Stage 5 and `sorry_inventory` regions are unchanged in the diff. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel. Phases 1 and 2 touch strictly disjoint files
and share no state, so they are territory-safe for parallel dispatch:
- Phase 1 territory: `agent-system/extensions/core/agents/general-implementation-hard-agent.md`
- Phase 2 territory: `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`
- Both read-only: `agent-system/extensions/core/agents/general-implementation-agent.md`

---

### Phase 1: Insert Canonical Checklist Contract into the Core Hard Agent [COMPLETED]

**Goal**: `general-implementation-hard-agent.md` carries the full canonical checklist contract in
place of its bare placeholder bullet, with its lettered-step structure and em-dash convention
intact.

**Tasks**:
- [x] Read `agent-system/extensions/core/agents/general-implementation-agent.md` lines 181-218 and
      copy the canonical block body (the text under `#### 4B-ii.`, from "After updating the
      progress file..." through the closing `**Note**:` paragraph) into a scratch buffer verbatim *(completed)*
- [x] Read `agent-system/extensions/core/agents/general-implementation-hard-agent.md` lines 152-195
      to confirm the Stage 4 structure matches the sites named in this plan before editing *(completed)*
- [x] Delete the single line `- For each completed checklist item: check off in plan file` from the
      `**B. Execute Steps**` bullet list, leaving the two surrounding B bullets untouched *(completed)*
- [x] Insert a new bold-label sub-section `**B-ii. Check Off Completed Items in Plan File**`
      containing the canonical block body verbatim, positioned immediately before the existing
      `**C. Verify Phase Completion** - Run phase verification criteria` line, separated by blank
      lines consistent with neighboring sub-sections *(completed)*
- [x] Confirm all four of the block's em-dashes survived the paste: the "canonical" parenthetical,
      the "particular title format" dash, and the skipped and altered deviation suffixes *(completed: em-dash count rose 18->22)*

**Timing**: 0.3 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly one line is deleted (the placeholder bullet at
line 174) and exactly one bold sub-section is added immediately before the `**C. Verify Phase
Completion**` line, with no other line in the file changed. Confirm at implementation time by
re-reading lines 152-195 before editing (line numbers may have drifted) and by
`git diff --stat -- agent-system/extensions/core/agents/general-implementation-hard-agent.md`
after: the diff must show a single contiguous hunk, one deletion plus the inserted block, and
nothing else.

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-hard-agent.md` - replace the
  placeholder B bullet with the canonical `**B-ii.**` sub-section before `**C.**`

**Verification**:
- `grep -c -- '- \[x\]'` on the file returns a non-zero count (baseline was 0)
- `grep -n 'Matching contract (canonical'` returns exactly one hit
- `grep -n '\*\*B-ii\. Check Off Completed Items in Plan File\*\*'` returns exactly one hit, at a
  line number lower than the `**C. Verify Phase Completion**` line
- `grep -c 'check off in plan file'` returns 0 (the bare placeholder is gone)
- All four bold lettered labels still present: `**A. Mark Phase In Progress**`,
  `**B. Execute Steps**`, `**C. Verify Phase Completion**`, `**D. Mark Phase Complete**`
- `grep -c '—'` returns 22 (baseline 18 + the block's 4; the deleted placeholder bullet had none)
- No `####` heading was introduced inside Stage 4's lettered-step region

---

### Phase 2: Insert Canonical Checklist Contract into the CSLib Hard Agent [COMPLETED]

**Goal**: `cslib-implementation-hard-agent.md` carries the same canonical contract verbatim, with
its Lean-specific B bullets, Stage 5 H9 wrap-up, and `sorry_inventory` requirements untouched.

**Tasks**:
- [x] Copy the canonical block body from
      `agent-system/extensions/core/agents/general-implementation-agent.md` (`#### 4B-ii.`) verbatim
      — identical text to Phase 1, em-dashes included; do NOT convert to ASCII `--` *(completed)*
- [x] Read `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` lines 201-240
      to confirm the Stage 4 structure and the Stage 5 boundary before editing *(completed)*
- [x] Delete the single line `- For each completed checklist item: check off in plan file` from the
      `**B. Execute Steps**, plus hard-mode additions:` bullet list, keeping the two Lean-specific
      bullets (`lean_goal`, `lean_multi_attempt`) in the list in their existing order *(completed)*
- [x] Insert `**B-ii. Check Off Completed Items in Plan File**` with the canonical block body
      verbatim, immediately before the existing `**C. Verify Phase Completion** - Run CSLib CI
      pipeline steps relevant to this phase:` line *(completed)*
- [x] Confirm Stage 5's H9 wrap-up, the 7-step CI pipeline list, and every `sorry_inventory`
      reference are unchanged *(completed: sorry_inventory count 10 unchanged, orchestrator-handoff.json count 4 unchanged)*

**Timing**: 0.3 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts exactly one line is deleted (the placeholder bullet at
line 211) and one bold sub-section added before the `**C. Verify Phase Completion**` line, with the
two Lean bullets, all four `.orchestrator-handoff.json` references, and every `sorry_inventory`
mention untouched. Confirm at implementation time by re-reading lines 201-240 before editing and by
`git diff -- agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` after: the
diff must contain no line mentioning `sorry_inventory`, `orchestrator-handoff`, `lean_goal`, or
`lean_multi_attempt`.

**Files to modify**:
- `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` - replace the
  placeholder B bullet with the canonical `**B-ii.**` sub-section before `**C.**`

**Verification**:
- `grep -c -- '- \[x\]'` returns a non-zero count (baseline was 0)
- `grep -n 'Matching contract (canonical'` returns exactly one hit
- `grep -n '\*\*B-ii\. Check Off Completed Items in Plan File\*\*'` returns exactly one hit, at a
  line number lower than the `**C. Verify Phase Completion**` line
- `grep -c 'check off in plan file'` returns 0
- `grep -c 'sorry_inventory'` and `grep -c 'orchestrator-handoff.json'` both return their
  pre-edit baselines
- `grep -c 'lean_goal\|lean_multi_attempt'` returns its pre-edit baseline
- `grep -c '—'` returns 8 (baseline 4 + the block's 4; the deleted placeholder bullet had none)

---

### Phase 3: Cross-File Verification and Deploy-Boundary Gate [COMPLETED]

**Goal**: Prove both insertions are byte-identical to the canonical source, that the diff is
confined to the two declared source-store paths, and that repo-wide gates still pass.

**Tasks**:
- [x] Extract the canonical block body from `general-implementation-agent.md` and the inserted
      block body from each hard file, then `diff` each pair — both diffs must be empty (byte
      equality, not "looks the same") *(completed: both diffs empty)*
- [x] Confirm all six annotation suffixes appear verbatim in each hard file: `*(completed)*`,
      `*(completed: {brief note})*`, `*(in progress)*`, and the three `*(deviation: ...)*` forms
      (skipped / altered / deferred) *(completed)*
- [x] Confirm `grep -n 'Task {P}\.{N}'` in each hard file returns hits ONLY inside the canonical
      block's "Do NOT assume a `**Task {P}.{N}**:` prefix" prose — never in a checklist-matching
      or annotation position *(completed: exactly one hit each, in the negated prose)*
- [x] Run `git diff --stat` and confirm exactly two paths changed, both under
      `agent-system/extensions/**`, with zero paths under `.claude/**` *(completed)*
- [x] Run `bash .claude/scripts/check-task-references.sh` and confirm it still reports
      `PASS: 0 unexempted task-reference occurrences` *(completed)*
- [x] Confirm neither file's `Stage 5` region appears in the diff *(completed)*

**Timing**: 0.4 hours

**Depends on**: 1, 2

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts the total change set is exactly two files. Confirm with
`git diff --name-only` returning precisely
`agent-system/extensions/core/agents/general-implementation-hard-agent.md` and
`agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`. If a third path appears,
stop and reconcile before closing the phase.

**Files to modify**:
- None (verification only; may correct a defect found in Phase 1 or 2 output)

**Verification**:
- Both canonical-block diffs are empty
- `check-task-references.sh` PASS
- `git diff --name-only` returns exactly the two declared paths
- No file under `.claude/**` modified

---

## Testing & Validation

- [x] Both hard-mode files instruct ticking individual plan checklist items
- [x] The instruction matches on existing item text and depends on no particular item-title format
- [x] All six annotation suffixes present verbatim in both files
- [x] `Task {P}.{N}` appears in both files only as the explicitly-negated placeholder inside the
      canonical prose
- [x] Hard-mode wrap-up (H9), `sorry_inventory`, territory, Stage 5a, and handoff contracts intact
- [x] Em-dash convention preserved in both files; no ASCII `--` introduced in annotation position
- [x] Zero writes under `.claude/**`
- [x] `bash .claude/scripts/check-task-references.sh` PASS

## Artifacts & Outputs

- Modified: `agent-system/extensions/core/agents/general-implementation-hard-agent.md`
- Modified: `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md`
- `specs/974_add_checklist_contract_to_hard_implementation_variants/summaries/01_*-summary.md`

## Recommended Follow-On Task (out of scope here, covered by no existing task)

Task 971 flagged, and this task's research re-verified by grep, that two further implementation
agents still carry the brittle literal `**Task {P}.{N}**:`-prefix idiom in their deviation-
annotation and summary-template lines:

- `agent-system/extensions/web/agents/web-implementation-agent.md`
- `agent-system/extensions/nvim/agents/neovim-implementation-agent.md`

Both show `- Skipped: `- [ ] **Task {P}.{N}**: {description} ...`` plus matching Altered/Deferred
lines and two `## Plan Deviations` template bullets each. This is the same brittle-prefix defect
class task 971 fixed in the core agent, in files outside this task's `file_scope`, and it is
covered by **no** existing task. Recommended: create a task applying the canonical loosened wording
to those two files.

Separately, `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` (the non-hard
cslib sibling) also still carries the brittle prefix; that one is already tracked as its own named
downstream task and needs no new task created.

## Rollback/Contingency

Both edits are additive text insertions in a single contiguous hunk per file, with no build
artifact and no state mutation. To revert either phase independently:

```bash
git checkout HEAD -- agent-system/extensions/core/agents/general-implementation-hard-agent.md
git checkout HEAD -- agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md
```

Note the destructive-git guard: if the tree is dirty, run
`bash .claude/scripts/git-snapshot.sh 974` first. Because the two files are independently
revertible and each phase commits separately, a defect in one file never forces reverting the
other.
