# Implementation Plan: Task #972

- **Task**: 972 - Add a plan-checklist mark-completed contract to cslib-implementation-agent.md
- **Status**: [IMPLEMENTING]
- **Effort**: 0.75 hours
- **Dependencies**: 971 (COMPLETED — established the canonical matching contract)
- **Research Inputs**: `specs/972_add_checklist_contract_to_cslib_implementation_agent/reports/01_add-checklist-contract-cslib.md`
- **Artifacts**: plans/01_add-checklist-contract-cslib.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`agent-system/extensions/cslib/agents/cslib-implementation-agent.md` is the only implementation
agent with zero working mark-completed instructions: its "Phase Status Updates (MANDATORY)"
section covers only the phase-heading `[NOT STARTED]` -> `[IN PROGRESS]` -> `[COMPLETED]`
transitions and deviation annotations, never the per-item checkboxes inside a phase. This plan
inserts one new `### Check Off Completed Items in Plan File` subsection quoting the canonical
prefix-free matching contract established by task 971, then verifies the result byte-for-byte
against the canonical source. Definition of done: the file instructs ticking both the phase
heading and the individual checklist items, the completion instruction depends on no particular
item-title format, and the two out-of-scope subsections are unchanged.

### Research Integration

Findings carried directly into this plan:

- The cslib extension lives in **this** repository at
  `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` — no cross-repo lookup is
  needed. Verified by direct file read.
- Canonical source located: `agent-system/extensions/core/agents/general-implementation-agent.md`,
  section `#### 4B-ii. Check Off Completed Items in Plan File` (lines 181-217).
- Insertion point: between the existing `### After Completing a Phase` (ends line 104) and
  `### When Deviating from Plan Steps` (starts line 106).
- Heading depth adapts `####` -> `###` (cslib's file uses flat `###` subsections under
  `## Phase Status Updates (MANDATORY)`; the canonical source nests one level deeper under a
  numbered stage). Structural fit, not a content paraphrase.
- **Canonical step 4 is omitted.** The research report's carve-out (Decisions section) is
  adopted: the task description explicitly instructs leaving the existing
  `### When Deviating from Plan Steps` subsection intact, and that subsection already covers
  deviation annotation. Copying step 4 would place a second, conflicting deviation block
  immediately above it — differing in both prefix assumption (`{existing item text}` vs
  `**Task {P}.{N}**: {description}`) and dash style (em-dash vs ASCII `--`). This is a
  deliberate, documented divergence from the delegation brief's "plus its four numbered steps",
  which was written before this task's specific step-4 conflict was discovered.

### Prior Plan Reference

No prior plan for this task. Task 971 (the predecessor that established the canonical wording)
is COMPLETED; its contribution here is the canonical text itself and the recorded cslib
dash-preservation caveat, both already folded into the research report.

### Roadmap Alignment

No `roadmap_path` was supplied in the delegation context and `roadmap_flag` was not set, so no
roadmap consultation was performed and no roadmap phases are included. (`specs/ROADMAP.md` does
exist in this repository; it was deliberately not read, per the read-only-when-supplied
contract.)

## Goals & Non-Goals

**Goals**:

- Insert a `### Check Off Completed Items in Plan File` subsection into
  `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` at the researched
  insertion point.
- Quote the canonical matching-contract paragraph and numbered steps 1-3 verbatim from
  `general-implementation-agent.md` (heading depth is the only permitted alteration).
- Leave the completion/in-progress annotation suffixes byte-identical to core's:
  `*(completed)*`, `*(completed: {brief note})*`, `*(in progress)*`.
- Verify no brittle-prefix matching (`**Task {P}.{N}**:`-shaped) survives in the newly added
  checklist-matching or annotation-format text.

**Non-Goals**:

- Editing the existing `### Before Starting a Phase` / `### After Completing a Phase`
  phase-heading subsections — confirmed correct, explicitly out of scope.
- Editing the existing `### When Deviating from Plan Steps` subsection. Its
  `**Task {P}.{N}**: {description}` prefix and ASCII `--` dashes stay exactly as they are.
  **Known residual, recorded not hidden**: that subsection therefore retains brittle-prefix
  matching in annotation-format position. This is the one place where the delegation brief's
  "no brittle-prefix matching survives in annotation-format position" bar cannot be met without
  violating the task's explicit scope carve-out. Scope wins; the residual is a follow-up
  candidate, not something this task silently fixes or silently passes over.
- Any write to `.claude/**`. That tree is a gitignored, disposable deploy artifact.
- Running the deploy/reload (`<leader>al`). Redeployment is the user's action.
- The hard-mode implementation-agent variants (`*-implementation-hard-agent.md`), named by task
  971 as a separate sibling concern.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Implementer copies canonical step 4 anyway (following 971's generic "four numbered steps" guidance), producing a conflicting deviation block above the existing one | H | M | Phase 1 Tasks name the omission explicitly; Phase 2 greps for a second `deviation: skipped` occurrence and fails if found |
| Em-dash / ASCII `--` churn: ASCII-ifying the two em-dashes inside the copied prose, or em-dashing the untouched deviation section | M | M | Phase 2 asserts exactly 3 `--`-bearing deviation lines survive unchanged and that the copied prose retains its em-dashes; Phase 1 Tasks state the rule per-region |
| Edit lands in `.claude/extensions/cslib/agents/...` (the deploy copy) instead of the source store | H | L | Phase 1 first Task is an explicit path assertion; the advisory `validate-meta-write.sh` PostToolUse hook also fires on `.claude/**` targets |
| Checklist-ticking confusion: this plan's own fenced insert-text contains literal `- [ ]` / `- [x]` lines that an over-eager ticker could match instead of the real Tasks items | L | M | The insert-text lives in a fenced code block under a clearly labelled reference section; a warning note precedes it |
| Heading-depth mismatch (`####` copied verbatim) breaks the file's subsection nesting | L | L | Phase 2 asserts the new heading is exactly `### Check Off Completed Items in Plan File` |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel. Here the two phases are strictly sequential.

### Phase 1: Insert the Check-Off Subsection [COMPLETED]

**Goal**: `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` gains one new
`### Check Off Completed Items in Plan File` subsection carrying the canonical prefix-free
matching contract plus numbered steps 1-3, positioned between `### After Completing a Phase` and
`### When Deviating from Plan Steps`.

**Tasks**:

- [x] Assert the edit target is `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` under `/home/benjamin/.config/nvim/`, and NOT any path under `.claude/` *(completed)*
- [x] Read `agent-system/extensions/core/agents/general-implementation-agent.md` lines 181-217 to obtain the canonical text firsthand rather than relying on any transcription *(completed)*
- [x] Read `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` lines 82-112 to confirm the current subsection boundaries and locate the exact insertion seam *(completed)*
- [x] Insert the new subsection after the closing fence of `### After Completing a Phase` and before the `### When Deviating from Plan Steps` heading, using the reference text in "Verbatim Insert Text" below *(completed)*
- [x] Confirm the heading is `### Check Off Completed Items in Plan File` (three hashes, matching sibling depth) and not the canonical `####` *(completed)*
- [x] Confirm canonical numbered step 4 and its three `*(deviation: ...)*` suffixes were NOT copied *(completed)*
- [x] Confirm the existing `### Before Starting a Phase`, `### After Completing a Phase`, and `### When Deviating from Plan Steps` subsections are byte-unchanged *(completed: git diff shows insertions only, zero deletions)*
- [x] Confirm no task-number citation was introduced (this file is a deliverable outside `specs/**`) *(completed)*

**Timing**: 0.4 hours

**Depends on**: none

**Verification Tier**: `prose`

**Scope Hypothesis**: This phase asserts a one-file scope (`file_scope` names exactly
`agent-system/extensions/cslib/agents/cslib-implementation-agent.md`) and an insertion seam at
"after current line 104, before current line 106". Both are hypotheses from the research report's
line-numbered read, not facts. Confirm at implementation time by reading lines 82-112 of the
target file before editing; if the subsection boundaries have shifted, locate the seam by heading
text (`### After Completing a Phase` / `### When Deviating from Plan Steps`) rather than by line
number, and record the actual line numbers observed.

**Files to modify**:

- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` — insert one new `###`
  subsection (~30 lines) between the two named existing subsections. No other region touched.

**Verification**:

- `grep -c '(completed)' agent-system/extensions/cslib/agents/cslib-implementation-agent.md`
  returns at least 1 (was 0 before this phase).
- `grep -n '^### ' agent-system/extensions/cslib/agents/cslib-implementation-agent.md` shows the
  four subsections in order: Before Starting a Phase, After Completing a Phase, Check Off
  Completed Items in Plan File, When Deviating from Plan Steps.
- `git diff --stat` on the file shows insertions only, zero deletions.
- `git diff` confirms every changed hunk lies inside the newly added prose region (the `prose`
  tier's diff read-through).

---

### Phase 2: Verify Byte-Identity and Prefix-Freedom [NOT STARTED]

**Goal**: Mechanically confirm the inserted contract matches core's byte-for-byte in the
load-bearing spans, that no brittle-prefix matching entered the new text, and that the untouched
deviation subsection kept its ASCII dash style.

**Tasks**:

- [ ] Assert the three completion/in-progress annotation suffixes in the new subsection are byte-identical to core's: `*(completed)*`, `*(completed: {brief note})*`, `*(in progress)*`
- [ ] Diff the copied span against canonical lines 183-206 plus the closing Note, confirming the only differences are the heading depth (`###` vs `####`), the omission of step 4, and the one-line cross-reference sentence appended to the Note
- [ ] Assert the new subsection contains zero occurrences of `**Task {P}.{N}**` — i.e. no brittle-prefix matching in checklist-matching or annotation-format position within the added text
- [ ] Assert `{existing item text}` appears in the new subsection as the matching placeholder
- [ ] Assert exactly three `*(deviation: ...)*` lines remain in the file, all inside `### When Deviating from Plan Steps`, all still using ASCII `--` (never em-dash) and still carrying their original `**Task {P}.{N}**: {description}` prefix
- [ ] Assert the two em-dashes inside the copied matching-contract prose were preserved as U+2014 (they are canonical prose, not annotation suffixes, so the cslib ASCII-dash caveat does not apply to them)
- [ ] Re-run the comparative count that established cslib as the outlier and record the new numbers for the summary
- [ ] Record the known residual (existing deviation subsection retains brittle-prefix matching, by explicit task-scope instruction) so it surfaces in the completion summary rather than being silently dropped

**Timing**: 0.35 hours

**Depends on**: 1

**Verification Tier**: `prose`

**Scope Hypothesis**: This phase asserts "exactly three `*(deviation: ...)*` lines remain" and
that the pre-change baseline was `(completed)` = 0 occurrences, `- [x]` = 1 occurrence. Both are
hypotheses from the research report. Confirm the baseline at implementation time against
`git show HEAD:agent-system/extensions/cslib/agents/cslib-implementation-agent.md` rather than
trusting the reported numbers, and report the observed counts.

**Files to modify**:

- None. This phase is read-only verification. Any defect it finds is corrected by re-editing
  `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` under Phase 1's contract,
  not by relaxing an assertion here.

**Verification**:

- Suffix byte-identity: for each of the three suffixes, the exact string is present in both
  `general-implementation-agent.md` and the new cslib subsection.
- `grep -c 'Task {P}.{N}'` restricted to the new subsection's line range returns 0.
- `grep -c 'deviation:' agent-system/extensions/cslib/agents/cslib-implementation-agent.md`
  returns 3.
- `grep -c 'deviation: skipped' ...` returns 1 (catches an accidentally duplicated step 4).
- No em-dash appears on any `deviation:` line; both em-dashes in the matching-contract paragraph
  are present.

---

## Verbatim Insert Text (reference for Phase 1)

**Warning to the implementing agent**: the fenced block below contains literal `- [ ]` and
`- [x]` markers as part of its content. They are template text to insert into the target file —
they are NOT this plan's own checklist items and must never be ticked. Only the `- [ ]` items
under each phase's **Tasks** heading are this plan's checklist.

Insert exactly this, between `### After Completing a Phase` and `### When Deviating from Plan Steps`:

````markdown
### Check Off Completed Items in Plan File

After updating the progress file, also update the plan file to reflect completed work.

**Matching contract (canonical — quote this block verbatim; do not paraphrase it)**: locate a
checklist item by its EXISTING item text, meaning whatever text already follows `- [ ]` in the
plan file. Do NOT assume a `**Task {P}.{N}**:` prefix, bold markup, or any other particular title
format — plans commonly carry free-form prose items such as `- [ ] {Step 1}` or
`- [ ] {Test criterion 1}`. Match on the item's core text and intent, tolerating minor whitespace
or formatting drift between plan authoring and implementation; never require a byte-exact match
against a template. Preserve the located item's text unchanged and rewrite only the leading
marker and the appended annotation. Below, `{existing item text}` denotes that already-present
text: it describes what to locate and preserve, and is never template syntax to inject into a
plan.

1. **Locate the current phase's Tasks section** in the plan file
2. **For each objective just completed**: Edit the corresponding checklist item, rewriting the
   leading `- [ ]` to `- [x]` and appending the completion annotation:
   - old_string: `- [ ] {existing item text}`
   - new_string: `- [x] {existing item text} *(completed)*`

   If a brief completion note adds value (e.g., "removed 9,611 files", "3 of 5 validators done"), append it:
   - new_string: `- [x] {existing item text} *(completed: {brief note})*`

3. **For the current in-progress objective** (if any): Leave as `- [ ]` but optionally append a note:
   - `- [ ] {existing item text} *(in progress)*`

**Note**: This step applies to any phase carrying `- [ ]` checklist syntax, whatever the item
wording. Skip it only when the phase has no checklist items at all; the progress file remains the
authoritative tracking mechanism. Deviation annotations (skipped, altered, deferred items) are
handled separately below in "When Deviating from Plan Steps."
````

Note on the two `**Task {P}.{N}**:` mentions inside that block: both are *negative* references —
"Do NOT assume a `**Task {P}.{N}**:` prefix". They are the opposite of brittle-prefix matching and
are required by the verbatim-quote mandate. Phase 2's prefix-freedom assertion targets
brittle-prefix use in *matching or annotation-format position*, which this block has none of.

## Testing & Validation

- [ ] `grep -c '(completed)'` on the target file returns >= 1 (baseline was 0)
- [ ] The four `###` subsections appear in the expected order
- [ ] The three completion/in-progress suffixes are byte-identical to core's
- [ ] Exactly three `deviation:` lines remain, all ASCII `--`, all in the untouched subsection
- [ ] `git diff --stat` shows insertions only on the one file in `file_scope`
- [ ] No file under `.claude/**` was written
- [ ] No task-number citation introduced outside `specs/**`
  (`bash .claude/scripts/check-task-references.sh` if available)

## Artifacts & Outputs

- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` — modified: one new
  `### Check Off Completed Items in Plan File` subsection (~30 lines inserted, 0 deleted)
- `specs/972_add_checklist_contract_to_cslib_implementation_agent/summaries/01_add-checklist-contract-cslib-summary.md`
  — execution summary, recording the observed before/after counts and the known residual
- `specs/972_add_checklist_contract_to_cslib_implementation_agent/progress/phase-{P}-progress.json`
  — per-phase progress files

## Rollback/Contingency

Single-file, insertion-only change. To revert:
`git checkout HEAD -- agent-system/extensions/cslib/agents/cslib-implementation-agent.md`
(safe only on a clean tree or after `bash .claude/scripts/git-snapshot.sh 972`; the pathspec
discard form is blocked by `guard-destructive-git.sh` on a dirty tree).

If Phase 2 finds a defect, correct the inserted text under Phase 1's contract and re-run Phase 2
— do not relax an assertion. If the canonical source turns out to differ from the research
report's transcription, the canonical file wins: re-copy from
`general-implementation-agent.md` and note the discrepancy in the summary.

Redeployment to `.claude/` and to the cslib repo happens through the user's `<leader>al` reload
and is outside this task's scope; nothing here depends on a deploy having run.
