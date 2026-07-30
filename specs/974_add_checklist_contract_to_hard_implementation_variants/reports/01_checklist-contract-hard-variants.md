# Research Report: Task #974

- **Task**: 974 - Add plan-checklist mark-completed contract to the two hard-mode implementation agents
- **Started**: 2026-07-29
- **Completed**: 2026-07-29
- **Effort**: ~30 minutes
- **Dependencies**: predecessor task establishing the canonical checklist-matching wording (already landed)
- **Sources/Inputs**: Codebase (agent-system/extensions/**), predecessor task's completion summary
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Executive Summary

- Both target files — `agent-system/extensions/core/agents/general-implementation-hard-agent.md`
  and `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` — reside in this
  nvim repo's source store (confirmed: `agent-system/extensions/cslib/` has no nested `.git`, it
  is a plain subdirectory of this repo, deployed outward to the separate cslib repo at reload
  time, not itself a separate repo).
- Both files currently have a single bare bullet, `- For each completed checklist item: check off
  in plan file`, with **zero** occurrences of `- [x]` or the literal `Task {P}.{N}` prefix —
  confirming the task description's empirical survey: no instruction of any kind exists yet, only
  a one-line placeholder needing expansion into the full canonical contract.
- The canonical block (`general-implementation-agent.md`, section `#### 4B-ii`) is fully
  extracted below, ready to paste verbatim into each file's Stage 4 "B. Execute Steps" area as a
  new `**B-ii. Check Off Completed Items in Plan File**` sub-section, immediately before each
  file's `**C. Verify Phase Completion**` step.
- Dash style: `cslib-implementation-hard-agent.md` already uses U+2014 em-dashes in its own prose
  (4 existing instances, e.g. "violation — correct the next step immediately") and has **no**
  pre-existing ASCII `--` deviation-annotation lines to preserve (unlike the non-hard
  `cslib-implementation-agent.md` sibling, which does use ASCII `--` in that specific position).
  Recommendation: use the canonical block's em-dashes unchanged in both hard-mode files — this
  matches `cslib-implementation-hard-agent.md`'s own existing convention and requires no
  dash-style deviation from the canonical wording.
- Neither hard-mode file's existing hard-mode structure (H9 wrap-up, `sorry_inventory`,
  territory/single-phase-focus contracts) needs to move or be restructured — the new sub-section
  slots in as a sibling of the existing lettered steps (A/B/C/D) without touching any of them.
- **Scope correction during this research pass**: I initially applied the edit directly to both
  files while acting as the research agent, then reverted it (verified via `git diff` showing a
  clean, empty diff on both paths) once I recognized that direct file edits belong to the
  implementation phase, not research. Both files are confirmed byte-identical to `HEAD` as of
  this report. The exact edit is fully specified below for the planning/implementation phases to
  apply.

## Context & Scope

Task 974 asks for the canonical plan-checklist mark-completed contract (established by a
predecessor task in the core, non-hard implementation agent) to be extended verbatim into the two
hard-mode variants, which currently have no per-item checklist instruction at all — a distinct
defect class from the "brittle prefix" bug the predecessor task fixed elsewhere. `file_scope` is
exactly the two files named above; the cslib non-hard sibling gap and the web/neovim brittle-prefix
gap are explicitly out of scope here (see Recommendations below for how they're tracked).

## Findings

### Codebase Patterns

**Canonical source** (verbatim, from `agent-system/extensions/core/agents/general-implementation-agent.md`,
section `#### 4B-ii. Check Off Completed Items in Plan File`, lines 181-217 at the time of this
research):

```
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

**Insertion points** (exact `old_string`/`new_string` shape for an implementer to apply):

1. `agent-system/extensions/core/agents/general-implementation-hard-agent.md` — inside Stage 4's
   lettered steps, replace the single line
   `- For each completed checklist item: check off in plan file`
   (currently the last bullet under `**B. Execute Steps** following the same pattern as base
   agent, plus:`) with a new `**B-ii. Check Off Completed Items in Plan File**` sub-section
   containing the canonical block above, sited immediately before the existing
   `**C. Verify Phase Completion** - Run phase verification criteria` line.
2. `agent-system/extensions/cslib/agents/cslib-implementation-hard-agent.md` — inside Stage 4's
   lettered steps, remove the bullet `- For each completed checklist item: check off in plan
   file` from the `**B. Execute Steps**, plus hard-mode additions:` list and insert the same new
   `**B-ii. Check Off Completed Items in Plan File**` sub-section (identical canonical-block
   content, em-dashes unchanged) immediately before
   `**C. Verify Phase Completion** - Run CSLib CI pipeline steps relevant to this phase:`.

Both insertions are additive only — no other line in either file needs to move, and none of the
Stage 5 H9 wrap-up / `sorry_inventory` / territory contracts are touched.

### External Resources

Not applicable — this is a self-contained internal documentation-contract task with no external
dependency.

### Recommendations

- Implement exactly the two insertions above, verbatim, in the planning/implementation phases.
- After the edit, verify (as the predecessor task did):
  - `grep -n 'Task {P}\.{N}'` in both files shows occurrences only inside the "Do NOT assume a
    `**Task {P}.{N}**:` prefix" canonical-block prose (a placeholder mention, not a real checklist
    pattern) — never in checklist-matching or annotation position.
  - `bash .claude/scripts/check-task-references.sh` (no-args, whole-repo scan) still reports
    `PASS: 0 unexempted task-reference occurrences` — confirmed clean on the current, unmodified
    tree during this research pass.
  - `git diff --stat` touches only the two `file_scope` paths.

## Decisions

- Confirmed `agent-system/extensions/cslib/` is part of this nvim repo's source store (no nested
  `.git`), not a separate repository — the task description's framing ("source lives in nvim,
  NOT in the cslib repo") refers to the *deployment target* (a separate cslib repo elsewhere
  receives a copy on reload), not the *source location*, which is unambiguously here.
- Recommend using em-dashes (matching the canonical block byte-for-byte) in both files, since
  neither hard-mode file has a pre-existing ASCII `--` convention in the specific annotation
  position that would need preserving (unlike the non-hard `cslib-implementation-agent.md`
  sibling, which is a separate, not-yet-done downstream task).

## Risks & Mitigations

- **Risk**: an implementer might restructure the hard-mode files' lettered-step numbering (A/B/C/D)
  when inserting a "B-ii" step. **Mitigation**: the predecessor's own file
  (`general-implementation-agent.md`) already uses this exact `4B-ii` sibling-step naming
  convention next to `4B-iii`, so `B-ii` is a proven, low-risk pattern to reuse without
  renumbering anything else.
- **Risk**: accidentally touching the `.orchestrator-handoff.json` / `sorry_inventory` sections
  while editing nearby Stage 4/5 content. **Mitigation**: the insertion point (before
  `**C. Verify Phase Completion**`) is well clear of Stage 5's wrap-up contract, which starts
  much further down in both files.

## Context Extension Recommendations

None — this is a meta task with narrow, already-documented scope; no new context-file gap was
identified beyond what the predecessor task already recorded.

## Appendix

### Related, out-of-scope gaps (not fixed here, for a future follow-up task)

- `agent-system/extensions/web/agents/web-implementation-agent.md` and
  `agent-system/extensions/nvim/agents/neovim-implementation-agent.md` still carry the brittle
  literal `**Task {P}.{N}**:`-prefix idiom in their deviation-annotation and summary-template
  lines (verified via grep during this research pass: both files show `- Skipped: `- [ ]
  **Task {P}.{N}**: {description} ...`` and matching Altered/Deferred lines, plus two
  `## Plan Deviations` template bullets each). This is the same gap the predecessor task's
  summary named as a follow-up; it remains unaddressed and is not in this task's `file_scope`.
- `agent-system/extensions/cslib/agents/cslib-implementation-agent.md` (the **non-hard** cslib
  sibling) also still carries the brittle prefix in its deviation-annotation lines (confirmed via
  grep: lines using ASCII `--` in `*(deviation: skipped -- {reason})*` etc., with the
  `**Task {P}.{N}**:` prefix). This is the separate, already-named downstream sibling task
  distinct from the present one (which targets only the two hard-mode files), and is not fixed
  here.

### Search queries / commands used

- `jq -r '.active_projects[]|select(.project_number==974)|.description' specs/state.json`
- `ls agent-system/extensions/cslib` and `find agent-system/extensions/cslib -name ".git"`
  (confirmed no nested repo)
- `grep -n "4B-ii\|Matching contract\|^#### \|^### "` against the canonical core file
- `grep -c '—'` / `grep -n -- '--'` against both hard-mode files and the non-hard cslib sibling to
  determine dash convention
- `grep -n 'Task {P}\.{N}\|Check Off\|checklist item'` against web/neovim/cslib non-hard agents
- `bash .claude/scripts/check-task-references.sh` (whole-repo, confirmed PASS on current tree)
