# Implementation Plan: Loosen implementation agents' plan-checklist match off the literal `**Task {P}.{N}**:` prefix

- **Task**: 971 - Loosen implementation agents' plan-checklist match off the literal `**Task {P}.{N}**:` prefix
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/971_loosen_implementation_agent_checklist_match/reports/01_loosen-checklist-match.md
- **Artifacts**: plans/01_loosen-checklist-match.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Three implementation-agent contracts instruct the agent to mark plan-checklist items complete by
Edit-matching a literal `- [ ] **Task {P}.{N}**: {description}` line shape that `planner-agent.md`
never emits — it emits free-form prose items (`- [ ] {Step 1}`). The match therefore finds nothing
and fails silently, observed live as 0 of 87 checklist items ticked across 4 genuinely-finished
phases. This plan rewrites the matching instruction in all three files to locate items by their
EXISTING item text, tolerating formatting drift, while leaving the annotation-suffix vocabulary
(`*(completed)*`, `*(deviation: skipped — {reason})*`, etc.) byte-for-byte unchanged. All edits
target `agent-system/extensions/**`; `.claude/**` is a gitignored, disposable deploy artifact and
is never edited.

Definition of done: no instruction in the three in-scope files requires the literal
`**Task {P}.{N}**:` prefix in order to locate or mark a checklist item; the deviation-annotation
suffixes are unchanged; and the canonical loosened wording exists at one named location that the
two downstream sibling tasks quote verbatim.

### Research Integration

- Confirmed root cause and per-file site mapping from the research report: `planner-agent.md`
  emits prose checklist items with no prefix template; the three in-scope files use the literal
  prefix in exactly two instruction roles — the dedicated mark-completed Edit instruction
  (general agent only) and the deviation-annotation example lines (all three).
- Adopted the report's recommendation that the loosened instruction match on the item's **core
  text and intent, tolerating minor formatting drift**, rather than requiring a byte-exact
  substring match — the report flags byte-exact matching as a way this could fail silently a
  second time.
- Adopted the report's finding that all three files ALREADY contain a loose, prefix-agnostic
  phrasing elsewhere ("ensure `- [x]` with `*(completed)*` annotation if not already annotated" in
  each file's context-pressure handoff path). Those lines are correct and are left untouched; this
  plan makes the brittle sites consistent with them rather than inventing new wording.
- Adopted the report's exclusion of the `## Plan Deviations` summary-template prose bullets
  (`- **Task {P}.{N}** skipped: {reason}`) — those are free prose in the implementation summary
  document, not an Edit match against a plan file, so they are not part of this bug.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

`specs/ROADMAP.md` exists but no `roadmap_path` was supplied in the delegation context and no
roadmap flag was set, so no roadmap phases are added and no roadmap item is claimed. ROADMAP.md is
not read, modified, or annotated by this plan.

## Goals & Non-Goals

**Goals**:
- Rewrite `general-implementation-agent.md`'s Stage 4B-ii mark-completed instruction so it locates
  items by existing item text, and make it the single canonical, verbatim-quotable home for this
  contract.
- Loosen the deviation-annotation example blocks in `general-implementation-agent.md` (both Stage
  4B-ii and Stage 4D-ii), `lean-implementation-agent.md`, and `nix-implementation-agent.md` off the
  literal prefix.
- Preserve the annotation-suffix vocabulary byte-for-byte, em-dash included.
- Point the lean and nix files at the canonical home by file + section name so the contract has one
  authority rather than three paraphrases.
- Repair the dangling cross-reference at `general-implementation-agent.md` Stage 4B-ii step 4,
  which currently cites `.claude/rules/plan-format-enforcement.md` "for the full deviation
  annotation format" — that file is a plan-authoring checklist and contains no deviation-annotation
  content whatsoever (verified: zero matches for "deviation" in
  `agent-system/extensions/core/rules/plan-format-enforcement.md`).

**Non-Goals**:
- `planner-agent.md` is NOT edited. Free-form prose checklist items are the accepted, more-readable
  going-forward format; this was decided upstream and is not relitigated here.
- The `## Plan Deviations` summary-template prose bullets in `general-implementation-agent.md` and
  `nix-implementation-agent.md` are NOT edited (non-checklist context, per Research Integration).
- `skill-orchestrate`'s drift-inspection prompt is NOT edited. Its `completed_items` count becomes
  correct on its own once items are actually ticked.
- `cslib-implementation-agent.md` and the hard-mode implementation variants are NOT edited here —
  they are the declared territory of the two downstream sibling tasks. This plan supplies the
  wording they consume; it does not pre-empt their edits.
- `web-implementation-agent.md` and `neovim-implementation-agent.md` are NOT edited (see the named
  gap under Risks).

## Canonical Wording (the coordination deliverable)

**Canonical home**: `agent-system/extensions/core/agents/general-implementation-agent.md`, section
`#### 4B-ii. Check Off Completed Items in Plan File`.

The two downstream sibling tasks (which extend this contract to the cslib implementation agent and
to the hard-mode implementation variants) MUST quote the **Matching contract** paragraph and the
numbered steps below verbatim from that section rather than paraphrasing them. Divergent
paraphrases across five agent files is the failure mode this section exists to prevent.

Phase 1 lands exactly this text (fenced here to keep it out of this plan's own live checklist):

```markdown
#### 4B-ii. Check Off Completed Items in Plan File

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

4. **For a step being deviated from** (skipped, altered, or deferred during execution):
   - Add a deviation entry to the progress file `deviations` array (see `.claude/context/formats/progress-file.md` for schema)
   - Annotate the checklist item inline, keeping these annotation suffixes exactly as written:
     - Skipped: `- [ ] {existing item text} *(deviation: skipped — {reason})*`
     - Altered: `- [x] {existing item text} *(deviation: altered — {what changed})*`
     - Deferred: `- [ ] {existing item text} *(deviation: deferred to task {N})*`

**Note**: This step applies to any phase carrying `- [ ]` checklist syntax, whatever the item
wording. Skip it only when the phase has no checklist items at all; the progress file remains the
authoritative tracking mechanism.
```

Two properties of the above are load-bearing and must survive implementation:

- The em-dash in `*(deviation: skipped — {reason})*` and `*(deviation: altered — {what changed})*`
  is U+2014, matching the current text in all three in-scope files byte-for-byte. The cslib agent
  uses a `--` ASCII fallback instead; the downstream task adopting this wording should preserve
  whichever dash its own file already uses rather than churning that file's punctuation.
- The old step-4 line `Reference: \`.claude/rules/plan-format-enforcement.md\` for the full
  deviation annotation format` is deliberately absent. It pointed at a file with no such content;
  Stage 4B-ii is itself the canonical home, so there is nothing to defer to.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Loosened wording is vague enough to fail silently again (agent can't find a match) | H | M | The Matching contract explicitly licenses matching on core text and intent with formatting-drift tolerance, and explicitly forbids requiring a byte-exact template match — the precise failure mode being designed out |
| Wording drifts between the three files, reproducing the inconsistency being fixed | M | M | One canonical home named above; lean and nix files carry a pointer to it rather than a restatement of the matching rule; Phase 4 diffs the three files' annotation lines against each other |
| An implementer accidentally rewords an annotation suffix while editing the surrounding line | M | M | Phase 4 verifies the six annotation suffixes are byte-identical to their pre-edit form via `git diff`, treating any suffix change as a defect |
| Two sibling agents on other phases touch the same file concurrently | M | L | Phases 2 and 3 own disjoint files; the only shared file (general agent) is owned exclusively by Phase 1 |
| Edits land in `.claude/**` instead of the source store and are wiped by the next redeploy | H | L | Every phase's file list is source-store-only; Phase 4 asserts `git status` shows no `.claude/**` modification |
| The same brittle idiom survives in agents nobody's task covers | M | H (already true) | Recorded as a named gap in Phase 4's handoff rather than silently absorbed — see below |

**Named gap, not fixed here**: the brittle literal-prefix idiom exists in **seven** source-store
files, not the three in declared scope. Beyond the three here and the ones the two sibling tasks
own (`cslib/agents/cslib-implementation-agent.md`,
`lean/agents/lean-implementation-hard-agent.md`), it also survives in
`web/agents/web-implementation-agent.md` and `nvim/agents/neovim-implementation-agent.md`, which no
task in this cluster covers. This plan does not widen scope to them; Phase 4 records the gap
explicitly so it can be picked up as a follow-up.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Land the canonical wording in the core general agent [COMPLETED]

**Goal**: `general-implementation-agent.md` carries the canonical, prefix-free matching contract at
Stage 4B-ii, and its Stage 4D-ii deviation examples match it.

**Tasks**:
- [x] Read `agent-system/extensions/core/agents/general-implementation-agent.md` around Stage 4B-ii and Stage 4D-ii to confirm current text before editing *(completed)*
- [x] Replace the whole `#### 4B-ii. Check Off Completed Items in Plan File` section body (from the heading through its closing `**Note**:` line, up to but not including `#### 4B-iii`) with the canonical block quoted in this plan's Canonical Wording section, verbatim *(completed)*
- [x] In Stage 4D-ii step 4, replace the three deviation example lines' `**Task {P}.{N}**: {description}` with `{existing item text}`, changing nothing else on those lines *(completed)*
- [x] In Stage 4D-ii step 2, confirm the existing cross-reference to "Stage 4B-ii Step 4 for annotation format" still resolves correctly after the rewrite; leave it if so *(completed: cross-reference resolves, unchanged)*
- [x] Confirm the context-pressure handoff line ("ensure `- [x]` with `*(completed)*` annotation if not already annotated") was NOT modified — it is already correct *(completed: verified unmodified)*
- [x] Confirm the `## Plan Deviations` summary-template prose bullets were NOT modified *(completed: verified unmodified)*

**Timing**: 40 minutes

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: The research report asserts 12 literal-prefix occurrences in this file,
distributed as 6 in Stage 4B-ii, 3 in Stage 4D-ii, 1 in a Stage 4D-ii JSON example comment context,
and 2 in the summary-template prose appendix. Confirm at implementation time with
`grep -c 'Task {P}\.{N}' agent-system/extensions/core/agents/general-implementation-agent.md`
before editing, and expect exactly 2 remaining after (the two intentionally-preserved
summary-template prose bullets). If the before-count is not 12 or the after-count is not 2,
enumerate every occurrence and reconcile rather than assuming the plan's numbers.

**Files to modify**:
- `agent-system/extensions/core/agents/general-implementation-agent.md` - replace Stage 4B-ii body with canonical block; genericize Stage 4D-ii step 4's three example lines

**Verification**:
- `grep -n 'Task {P}\.{N}' <file>` returns exactly the 2 summary-template prose lines
- `grep -c 'existing item text' <file>` returns at least 9 (6 in the canonical block, 3 in Stage 4D-ii)
- The six annotation suffixes (`*(completed)*`, `*(completed: {brief note})*`, `*(in progress)*`, and the three `*(deviation: ...)*` forms) appear with unchanged spelling and U+2014 em-dashes; confirm via `git diff` that no suffix text changed
- `git status --short` shows only this one file modified, and no path under `.claude/`

---

### Phase 2: Loosen the lean agent's deviation annotations [COMPLETED]

**Goal**: `lean-implementation-agent.md`'s deviation-annotation block is prefix-free and points at
the canonical home.

**Tasks**:
- [x] Read the `### When Deviating from Plan Steps` section of `agent-system/extensions/lean/agents/lean-implementation-agent.md` *(completed)*
- [x] Replace `**Task {P}.{N}**: {description}` with `{existing item text}` on each of the three annotation-format lines, changing nothing else on them *(completed)*
- [x] Add one sentence to that section stating that checklist items are located by their existing item text (no `**Task {P}.{N}**:` prefix assumed), and naming `general-implementation-agent.md`'s Stage 4B-ii as the canonical matching contract *(completed)*
- [x] Confirm the file's existing loose phrasing in the context-pressure handoff path was NOT modified *(completed: verified unmodified)*

**Timing**: 15 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: The research report asserts 3 literal-prefix occurrences in this file, all
three inside the `### When Deviating from Plan Steps` annotation-format list. Confirm with
`grep -n 'Task {P}\.{N}' agent-system/extensions/lean/agents/lean-implementation-agent.md` before
editing; expect 0 remaining after. A before-count other than 3 means an unmapped site exists —
enumerate it rather than editing only the expected lines.

**Files to modify**:
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` - genericize three annotation lines; add canonical-home pointer

**Verification**:
- `grep -c 'Task {P}\.{N}' <file>` returns 0
- The three `*(deviation: ...)*` suffixes are byte-identical to their pre-edit form (`git diff` shows change only to the item-text placeholder)
- `git status --short` shows no path under `.claude/`

---

### Phase 3: Loosen the nix agent's deviation annotations [COMPLETED]

**Goal**: `nix-implementation-agent.md`'s deviation-annotation block is prefix-free and points at
the canonical home.

**Tasks**:
- [x] Read the step `5. **Annotate deviations in plan file**` region and the Stage 4D-ii region of `agent-system/extensions/nix/agents/nix-implementation-agent.md` *(completed)*
- [x] Replace `**Task {P}.{N}**: {description}` with `{existing item text}` on each of the three annotation-format lines in step 5, changing nothing else on them *(completed)*
- [x] Add one sentence to step 5 stating that checklist items are located by their existing item text (no `**Task {P}.{N}**:` prefix assumed), and naming `general-implementation-agent.md`'s Stage 4B-ii as the canonical matching contract *(completed)*
- [x] Confirm the Stage 4D-ii cross-reference to "Step C.5 for format" still resolves after the edit; leave it if so *(completed: resolves, unchanged)*
- [x] Confirm the `## Plan Deviations` summary-template prose bullets and the context-pressure handoff line were NOT modified *(completed: verified unmodified; note the nix file has no separate context-pressure handoff line to begin with)*

**Timing**: 20 minutes

**Depends on**: 1

**Verification Tier**: local

**Scope Hypothesis**: The research report asserts 5 literal-prefix occurrences in this file: 3 in
step 5's annotation list and 2 in the summary-template prose appendix. Confirm with
`grep -n 'Task {P}\.{N}' agent-system/extensions/nix/agents/nix-implementation-agent.md` before
editing; expect exactly 2 remaining after (the preserved prose bullets). Reconcile by enumeration
if either count differs.

**Files to modify**:
- `agent-system/extensions/nix/agents/nix-implementation-agent.md` - genericize three annotation lines in step 5; add canonical-home pointer

**Verification**:
- `grep -n 'Task {P}\.{N}' <file>` returns exactly the 2 summary-template prose lines
- The three `*(deviation: ...)*` suffixes are byte-identical to their pre-edit form
- `git status --short` shows no path under `.claude/`

---

### Phase 4: Cross-file verification and downstream handoff [COMPLETED]

**Goal**: The three files are mutually consistent, the annotation vocabulary is provably unchanged,
and the canonical-home pointer plus the named gap are recorded for the downstream siblings.

**Tasks**:
- [x] Run `grep -rn 'Task {P}\.{N}' agent-system/extensions/{core,lean,nix}/agents/*implementation-agent.md` and confirm every surviving hit is a `## Plan Deviations` summary-template prose bullet — zero hits in any checklist-matching or annotation-format position *(completed: 7 hits survive, not 4 — see deviation note below; zero are in checklist-matching or annotation-format position, which is the actual invariant)*
- [x] Diff the three files' deviation-annotation lines against each other and confirm the suffix text is identical across all three *(completed: all three `*(deviation: ...)*` forms and `*(completed...)*`/`*(in progress)*` are byte-identical, em-dashes included)*
- [x] Confirm via `git diff` across all three files that no annotation suffix, and no already-loose phrasing, was altered *(completed)*
- [x] Run `bash .claude/scripts/check-task-references.sh` and confirm it passes (the placeholder `{N}` in `deferred to task {N}` is a placeholder, not a citation, and must not trip the gate) *(completed: PASS, 0 unexempted occurrences)*
- [x] Run `bash .claude/scripts/check-extension-docs.sh` and confirm no new failure was introduced *(completed: core extension FAILs on 37 pre-existing literature/zotero deploy-drift advisories, unrelated to these edits — see deviation note below; all other extensions PASS)*
- [x] Confirm `git status --short` lists no modified path under `.claude/` *(completed: confirmed)*
- [x] Record in the implementation summary: the canonical home (`general-implementation-agent.md`, section `#### 4B-ii. Check Off Completed Items in Plan File`) that the two downstream sibling tasks must quote verbatim, and the em-dash-vs-`--` note for the cslib file *(completed)*
- [x] Record in the implementation summary the named gap: `web/agents/web-implementation-agent.md` and `nvim/agents/neovim-implementation-agent.md` still carry the brittle idiom and are covered by no task in this cluster *(completed)*

**Timing**: 20 minutes

**Depends on**: 1, 2, 3

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts that exactly 4 `**Task {P}.{N}**` occurrences survive
across the three files (2 core, 2 nix, 0 lean), all in `## Plan Deviations` summary-template
prose. That figure is derived from Phases 1-3's own confirmed before/after counts, so confirm it
against those phases' actual recorded results rather than against this plan's prediction. Any
divergence is a Phase 1-3 defect to reconcile, not a number to adjust here.

**Files to modify**:
- None (verification and summary-recording only)

**Verification**:
- All greps above return the expected counts
- Both lint scripts exit 0 (or exit with only pre-existing, demonstrably unrelated failures, which must be quoted in the summary rather than waved past)
- The summary names the canonical home and the named gap explicitly

## Testing & Validation

- [x] Zero literal-prefix occurrences remain in any checklist-matching or annotation-format position across the three in-scope files *(completed)*
- [x] Exactly four `**Task {P}.{N}**` occurrences survive across the three files, all in `## Plan Deviations` summary-template prose (2 in the core agent, 2 in the nix agent, 0 in the lean agent) *(deviation: altered — actual count is 7, not 4: the 4 predicted summary-template bullets survive unchanged as predicted, PLUS 3 additional explanatory-prose mentions of the literal pattern that were required by the plan's own instructions — the canonical block's "Do NOT assume a `**Task {P}.{N}**:` prefix..." sentence (quoted verbatim per this plan's own mandate) in the core file, and the pointer sentences this plan's Phase 2/3 tasks explicitly instructed adding to the lean and nix files ("no `**Task {P}.{N}**:` prefix assumed"). None of the 7 are in checklist-matching or annotation-format position, which is the invariant this bullet exists to protect, and that invariant holds*
- [x] All six annotation suffixes are byte-for-byte unchanged, U+2014 em-dashes included *(completed)*
- [x] `check-task-references.sh` passes *(completed)*
- [x] `check-extension-docs.sh` introduces no new failure *(deviation: altered — core extension reports FAIL, but on 37 pre-existing literature/zotero deploy-drift advisories unconnected to any file this plan touches; not a new failure introduced by this work)*
- [x] No file under `.claude/` is modified *(completed)*

## Artifacts & Outputs

- `agent-system/extensions/core/agents/general-implementation-agent.md` (modified — canonical home)
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` (modified)
- `agent-system/extensions/nix/agents/nix-implementation-agent.md` (modified)
- `specs/971_loosen_implementation_agent_checklist_match/summaries/01_loosen-checklist-match-summary.md` (new)

## Rollback/Contingency

All changes are markdown-only edits to three files in a git-tracked source store, with no
generated or derived output. To revert: `git checkout HEAD -- <the three paths>` after confirming
the working tree holds no other uncommitted work on them (per the destructive-git rule, snapshot
first if it does). No deploy step is triggered by these edits; the user's redeploy keybinding
propagates whatever state the source store is in, so reverting the source store fully reverts the
behavior.

## Note on This Plan's Own Drift Metric

This plan quotes checklist-annotation templates inside a fenced code block, including literal
`- [ ]` and `- [x]` markers. A drift metric that counts raw `- [x]` occurrences in this file will
over-count completed items by the number of quoted `- [x]` templates (3 in the Canonical Wording
block). This is expected and is a property of the plan quoting the contract it is changing, not a
sign of work being misreported.
