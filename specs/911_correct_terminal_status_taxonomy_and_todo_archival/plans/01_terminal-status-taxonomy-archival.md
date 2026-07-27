# Implementation Plan: Task #911

- **Task**: 911 - correct_terminal_status_taxonomy_and_todo_archival
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/911_correct_terminal_status_taxonomy_and_todo_archival/reports/01_terminal-status-taxonomy-todo-archival.md
- **Artifacts**: plans/01_terminal-status-taxonomy-archival.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`/todo`'s archival scan matches only `status == "completed"` and `status == "abandoned"`, so
tasks that reach the genuinely-terminal `expanded` state can never be archived. The fix is to
widen both archival sites (`commands/todo.md` and `skills/skill-todo/SKILL.md`) to include
`expanded`, route those tasks into `completed_projects`, exclude them from ROADMAP.md matching
the way meta tasks already are, and add a narrow defer guard that holds back an expanded parent
while any of its `subtasks[]` are still non-terminal. Separately, one conflated documentation
line in `merge-sources/claudemd.md` — the only place in the tree that groups `BLOCKED`/`PARTIAL`
with `ABANDONED`/`EXPANDED` under a single "Terminal/exception states" label — is split into two
correctly-labelled bullets. Done when all three files carry the corrected behavior and no
archival filter anywhere admits `partial` or `blocked`.

### Research Integration

The research report established, and this plan takes as settled:

- The bug is confirmed at both sites: `commands/todo.md` (documented scan at lines 27-28, live
  jq `del()` filter at line 400) and `skills/skill-todo/SKILL.md` (Stage 2 `ScanTasks`, lines
  78-87).
- `skill-todo/SKILL.md`'s own Stage 2.5 `TopicRevision` (lines 94-99) *already* excludes
  `expanded` alongside `completed`/`abandoned`. This is in-file proof the omission is an
  incremental-maintenance gap, not a design decision — and it is the reference pattern for the
  Stage 2 fix.
- The taxonomy is correct at its authoritative source (`context/standards/status-markers.md`,
  plus ~25 agreeing enforcement sites): terminal = `{completed, abandoned, expanded}`;
  `partial`/`blocked` are non-terminal and resumable.
- `merge-sources/claudemd.md` line 39 is the single defective statement.
- Archive-array convention is binary (`completed_projects` for completed, `archived_projects`
  for abandoned); `expanded` joins `completed_projects` — no third array.
- Cross-task artifact-path reachability breakage is real but pre-existing and system-wide;
  adding `expanded` creates no new category of risk. Only the narrow subtasks-defer guard is in
  scope.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap context was provided in the delegation. `specs/ROADMAP.md` was not consulted and must
not be modified by this task.

## Goals & Non-Goals

**Goals**:
- `/todo` archives tasks with `status == "expanded"` at both archival sites, routing them into
  `archive/state.json`'s `completed_projects` array.
- Expanded tasks are excluded from ROADMAP.md item matching, the same way meta tasks already are.
- An expanded parent is deferred (left active for a later `/todo` run) while any task listed in
  its `subtasks[]` is still present in `active_projects` with a non-terminal status.
- `merge-sources/claudemd.md` distinguishes genuinely-terminal states from non-terminal exception
  states in two separate bullets.
- The two archival sites stay mutually consistent — no third divergence introduced.

**Non-Goals**:
- Adding `partial` or `blocked` to any archival filter, anywhere. (Hard constraint.)
- Any general cross-task artifact reachability fix (symlinks, pointer stubs, reference
  rewriting, link checking). Explicitly rejected by the research as out of proportion and
  undermined by vault renumbering.
- Editing any generated `.claude/**` file, including any generated `CLAUDE.md`.
- Touching `scripts/archive-task.sh` (dead helper, outside file scope), `context/standards/
  status-markers.md` (already correct), or `specs/ROADMAP.md`.
- Changing `commands/todo.md`'s git commit message string at line 803 (`todo: archive {N}
  completed tasks`) — it is mirrored by `.claude/rules/git-workflow.md`, which is outside file
  scope. Its divergence from `skill-todo/SKILL.md`'s `todo: archive {N} tasks` is pre-existing
  and stays as-is.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The Step 5B blanket `del()` filter deletes a deferred expanded parent from `active_projects` even though the guard excluded it from the archive list | H | H | Phase 3 makes the `del()` filter explicitly subtract the deferred parent numbers. This is the single most load-bearing correctness detail in the plan; it is called out in Phase 3's tasks and re-checked in Phase 5. |
| Widening filters accidentally admits `partial`/`blocked` | H | L | Phase 5 greps both files for `partial`/`blocked` inside any archival selector; the hard constraint is restated in every phase touching a filter. |
| The two archival sites drift again (the exact failure this task is fixing) | M | M | Phase 4 mirrors Phase 2+3 decisions deliberately rather than being authored independently; Phase 5 diffs the two sites' status lists against each other. |
| Edits land in `.claude/**` instead of `agent-system/extensions/**` | H | L | SOURCE-STORE RULE restated per-phase; Phase 5 verifies the working-tree diff touches only the three source files. |
| Task-number citations leak into deliverable files | M | M | Provenance in these three files must cite durable anchors (stage names, section headings, `status-markers.md`) — never task numbers. Phase 5 greps for literal `task <digits>` outside `specs/**`. |
| An expanded parent with no `subtasks[]` field (hand-set status) is treated as blocked forever | M | L | The guard treats a missing/empty `subtasks[]` as "nothing blocking" and archives normally; specified explicitly in Phase 3. |
| A subtask absent from `active_projects` (already archived) is misread as blocking | M | M | The guard treats an empty status lookup as non-blocking; specified explicitly in Phase 3. |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 2 |
| 3 | 4 | 3 |
| 4 | 5 | 1, 3, 4 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Split the conflated terminal-status bullet in the merge source [COMPLETED]

**Goal**: `merge-sources/claudemd.md` stops labelling `BLOCKED`/`PARTIAL` as terminal.

**Tasks**:
- [x] Read `agent-system/extensions/core/merge-sources/claudemd.md` around the "Status Markers"
      subsection (line 39 in the current file) to confirm the exact current text before editing.
      *(completed)*
- [x] Replace the single bullet

      `- `[BLOCKED]`, `[ABANDONED]`, `[PARTIAL]`, `[EXPANDED]` - Terminal/exception states`

      with two bullets that separate the two categories, e.g.:

      ```
      - `[ABANDONED]`, `[EXPANDED]` - Terminal states (no further transitions)
      - `[BLOCKED]`, `[PARTIAL]` - Exception states (non-terminal; any command can resume from these)
      ```
      *(completed)*
- [x] Confirm the surrounding bullets (lines 33-38: `[NOT STARTED]`, research/planning phases,
      the `[IMPLEMENTING]` termini, the `[PR READY]` rows) are left byte-for-byte unchanged.
      *(completed)*
- [x] Do NOT edit any generated `CLAUDE.md`. The deployed copy picks this up on next
      regeneration. *(completed)*

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/merge-sources/claudemd.md` - split one bullet into two

**Verification**:
- The file contains no line grouping `BLOCKED` or `PARTIAL` with the word "Terminal".
- `[COMPLETED]` remains covered by the `[IMPLEMENTING] -> [COMPLETED]` rows above; the new
  terminal bullet does not need to restate it, but if it does, it must not contradict them.
- `git status --short` shows no modification under `.claude/`.

---

### Phase 2: Widen `commands/todo.md` archival to include `expanded` [COMPLETED]

**Goal**: `/todo`'s command definition scans, filters, routes, and reports `expanded` tasks
alongside `completed`/`abandoned`, and excludes them from ROADMAP.md matching.

**Hard constraint**: no filter in this phase may admit `partial` or `blocked`.

**Tasks**:
- [x] Frontmatter line 2 (`description: Archive completed and abandoned tasks`) and body line 10
      (`Archive completed and abandoned tasks to clean up active task list.`): update both to
      name all three archivable statuses. *(completed)*
- [x] Step 2 "Scan for Archivable Tasks" (lines 26-32): add a third bullet
      `- Tasks with status = "expanded"` to the state.json list, and `- Entries marked [EXPANDED]`
      to the TODO.md cross-reference list. *(completed)*
- [x] Step 3.5.1 (lines 153-167): expanded tasks must be excluded from ROADMAP.md matching for
      the same reason meta tasks are — an expanded task has no `completion_summary` of its own by
      construction (its subtasks carry the deliverables). Rename the two buckets from
      `meta_tasks[]` / `non_meta_tasks[]` to `roadmap_excluded_tasks[]` /
      `roadmap_eligible_tasks[]`, and route a task into the excluded bucket when
      `task_type == "meta"` OR `status == "expanded"`. Add a one-line comment stating the
      structural reason (no `completion_summary` by construction) so a future reader does not
      "fix" this by requiring one. *(completed)*
- [x] Update the two downstream references to the renamed buckets: the loop header at line 197
      (`for task in "${non_meta_tasks[@]}"`) and the Track list at lines 249-254 (the
      `meta_tasks[]` / `non_meta_tasks[]` descriptions). *(completed: also updated the Step
      3.5.3 heading/comment prose from "non-meta" to "roadmap-eligible" for consistency)*
- [x] Step 5A prose (line 392): state that `completed` AND `expanded` tasks go to
      `completed_projects`, and `abandoned` tasks go to `archived_projects`. Do not introduce a
      third array. *(completed)*
- [x] Step 5B (lines 396-402): widen the `del()` filter to
      `select(.status == "completed" or .status == "abandoned" or .status == "expanded")`,
      and update the explanatory comment on line 398 to match. Keep the `del()` form — it is the
      Issue #1132-safe pattern and must not be rewritten as `map(select(... != ...))`.
      NOTE: Phase 3 amends this same filter again with the deferred-parent exclusion; write it
      here in a shape that is easy to extend. *(completed)*
- [x] Step 5D header (line 412, `For each archived task (completed or abandoned):`): include
      expanded. *(completed)*
- [x] Step 4 dry-run output template (lines 264-272): add an `Expanded:` block alongside
      `Completed:` and `Abandoned:`. *(completed)*
- [x] Step 7 output template (line 836, `Tasks: {C} completed, {A} abandoned`): add an expanded
      count. *(completed)*
- [x] Notes > "Task Archival" (line 869 onward): update the prose to describe the three
      archivable statuses and state plainly that `partial` and `blocked` are NOT archivable
      because they are resumable, citing `status-markers.md` as the authority. Use durable
      anchors only — no task numbers. *(completed)*

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `agent-system/extensions/core/commands/todo.md` - scan, filter, routing, roadmap exclusion,
  dry-run/output templates, Notes

**Verification**:
- `grep -n 'status == "completed" or .status == "abandoned"' agent-system/extensions/core/commands/todo.md`
  returns no hit that lacks `or .status == "expanded"`.
- `grep -n 'partial\|blocked' agent-system/extensions/core/commands/todo.md` returns nothing
  inside an archival selector.
- No occurrence of `non_meta_tasks` or `meta_tasks` remains unrenamed.
- `git status --short` shows no modification under `.claude/`.

---

### Phase 3: Add the subtasks-defer guard to `commands/todo.md` [COMPLETED]

**Goal**: An expanded parent is not archived while any of its subtasks is still active and
non-terminal, and the deferral is honored by every downstream step in the same run.

**Tasks**:
- [x] In Step 3 "Prepare Archive List" (lines 125-132), after the archivable tasks are
      collected, add a guard pass that partitions them into `archivable_tasks[]` (proceeds) and
      `deferred_expanded[]` (held back). Guard semantics:
      - Non-`expanded` tasks pass through untouched.
      - For an `expanded` task, read `.subtasks[]?` from its state.json entry.
      - A missing, null, or empty `subtasks` array means nothing is blocking — archive normally.
      - For each subtask number, look up its status in `active_projects`. An empty result means
        the subtask is already archived — not blocking.
      - A subtask whose status is `completed`, `abandoned`, or `expanded` is terminal — not
        blocking.
      - Any other status blocks: the parent goes to `deferred_expanded[]` with its blocking count.
      - Use a `case` statement for the status classification rather than `!=` comparisons, per
        the jq/shell escaping guidance in the Notes section of this same file.
      *(completed)*
- [x] Record `deferred_expanded_nums[]` (bare project numbers) for use by the steps below.
      *(completed)*
- [x] **Amend the Step 5B `del()` filter** so a deferred parent is not removed from
      `active_projects` even though its status matches. The blanket status filter alone is wrong
      here — without this, the guard defers the archive-list entry but the parent is still
      deleted from state.json, silently losing the task. Pass the deferred numbers in and subtract
      them, using `index(...) == null` (never `!=`).
      *(completed: deviation — the plan's literal snippet `($deferred | index(.project_number))`
      does not parse the way intended. After the `$deferred |` pipe, `.` inside `index()`'s
      argument rebinds to `$deferred` itself, not to the array element being tested, so jq raises
      "Cannot index array with string \"project_number\"". Verified this failure directly against
      a representative state.json fixture, then implemented and re-verified the corrected form
      `. as $item | ($deferred | index($item.project_number))`, which binds the element to `$item`
      before the pipe changes `.`'s context. `deferred_json` defaults to `[]` when nothing was
      deferred, confirmed by test.)*
- [x] Confirm Step 5A (archive/state.json insertion) and Step 5D (directory move) both iterate
      the guard-filtered archive list, not a freshly-recomputed status match. If either
      re-derives its own list from status, add an explicit note that it must consume the
      guard-filtered list. *(completed)*
- [x] Step 4 dry-run output: add a `Deferred (expanded, subtasks still active):` block listing
      each held-back parent and its blocking subtask count, so the deferral is visible before
      any mutation. *(completed)*
- [x] Step 7 output: report the deferred count. *(completed)*
- [x] Notes > "Task Archival": document the guard in one short paragraph — expanded parents wait
      until their subtasks go terminal, so a subtask still being worked can read its parent's
      artifacts in place. State explicitly that this guard addresses only the parent/child case
      and that general cross-task artifact citations remain a known, pre-existing limitation of
      archival (plain `mv`, plus vault renumbering). Durable anchors only — no task numbers.
      *(completed)*

**Timing**: 0.5 hours

**Depends on**: 2

**Files to modify**:
- `agent-system/extensions/core/commands/todo.md` - Step 3 guard, Step 5B filter amendment,
  Step 4/7 reporting, Notes

**Verification**:
- The Step 5B filter contains both the three-status match and the deferred-number subtraction.
- No `!=` appears in any jq expression added by this phase.
- The dry-run template shows deferred parents.
- A reader can answer "what happens to an expanded parent with an active subtask?" from the
  Notes section alone.

---

### Phase 4: Mirror the fix in `skills/skill-todo/SKILL.md` [COMPLETED]

**Goal**: The skill's archival path behaves identically to the command definition — same three
statuses, same routing, same defer guard, same reporting.

**Method**: Mirror the decisions made in Phases 2 and 3 rather than re-deriving them. Where the
two files' structures differ, prefer behavioral equivalence over textual sameness.

**Tasks**:
- [x] Frontmatter `description` (line 3), `<task_context>` (line 14), and `<task>` (line 19):
      update the "completed and abandoned" phrasing to name all three archivable statuses.
      *(completed)*
- [x] Stage 2 `ScanTasks` (lines 78-87): add `4. Identify tasks with status = "expanded"` (and
      renumber the following steps), extend the TODO.md cross-reference, and track
      `expanded_count` alongside `completed_count` / `abandoned_count`. Reference Stage 2.5
      `TopicRevision`'s existing three-status exclusion (lines 94-99) as the in-file precedent.
      *(completed)*
- [x] Stage 2 `ScanTasks`: add the same subtasks-defer guard specified in Phase 3, with identical
      semantics (missing/empty `subtasks` = not blocking; subtask absent from `active_projects` =
      not blocking; subtask in `completed`/`abandoned`/`expanded` = not blocking; anything else
      blocks). Track `deferred_expanded[]` and `deferred_count`. *(completed: reused the
      Phase-3-corrected guard shell logic verbatim, including the same `case` classification —
      no separate bug to re-fix here since this stage does not duplicate the Step 5B `del()`
      filter's `index()` expression)*
- [x] Stage 2.5 `TopicRevision`: leave unchanged — already correct. *(completed: verified
      byte-for-byte unchanged)*
- [x] Stage 5 `ScanRoadmap` (lines 189-212): state explicitly that expanded tasks are excluded
      from ROADMAP.md matching, with the same structural reason as Phase 2 (no
      `completion_summary` by construction). The stage currently iterates "each completed task",
      so this is a clarity edit that prevents a future widening, not a behavior change.
      *(completed)*
- [x] Stage 7 `HarvestMemories` (lines 227-265): leave scoped to completed tasks. Add a
      one-line note that expanded tasks are deliberately not harvested — their work product and
      memory candidates belong to their subtasks. Do not widen this stage. *(completed)*
- [x] Stage 10 `ArchiveTasks` (lines 347-413): route `expanded` tasks to `completed_projects`
      (sub-step 1), and ensure the `active_projects` removal (sub-step 2) excludes deferred
      parents exactly as Phase 3 specifies for the command. Sub-steps 3 (TODO.md removal) and 4
      (directory move) must consume the guard-filtered list. *(completed)*
- [x] Stage 8 `DryRunOutput` (line 272): extend the archive-counts line to include expanded, and
      add a deferred line in the same one-line-summary style used by the memory-candidate and
      reconciliation lines (omit or show `none` consistently with the neighbours). *(completed)*
- [x] Stage 13 `UpdateChangelog` (lines 776-783): the per-task entry already records `status`,
      so expanded entries flow through; add a short note confirming expanded is a valid archived
      status in CHANGE_LOG entries. *(completed)*
- [x] Stage 15 `GitCommit` (line 836): add expanded to the enumerated counts in the commit
      message. The message template itself (`todo: archive {N} tasks`) stays as-is. *(completed)*
- [x] Stage 16 `OutputResults` (line 844): extend "Archived tasks (completed/abandoned)" to
      include expanded, and report the deferred count. *(completed)*

**Timing**: 0.75 hours

**Depends on**: 3

**Files to modify**:
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` - Stages 2, 5, 7, 8, 10, 13, 15, 16
  plus the frontmatter/task-description lines

**Verification**:
- Every stage that enumerates archivable statuses lists exactly `completed`, `abandoned`,
  `expanded` — never `partial` or `blocked`.
- The defer-guard semantics in Stage 2 match Phase 3's bullet-for-bullet.
- Stage 2.5's existing three-status exclusion is untouched.
- `git status --short` shows no modification under `.claude/`.

---

### Phase 5: Cross-site consistency and constraint verification [COMPLETED]

**Goal**: Confirm the two archival sites agree, the hard constraints held, and nothing landed
outside the three in-scope source files.

**Tasks**:
- [x] Diff the two sites' status handling by hand: for each of scan, archive-array routing,
      `active_projects` removal, roadmap exclusion, defer guard, and reporting, confirm
      `commands/todo.md` and `skills/skill-todo/SKILL.md` describe the same behavior.
      *(completed: both sites scan/track all three statuses, route completed+expanded to
      completed_projects and abandoned to archived_projects, apply the identical subtasks-defer
      guard with matching four-edge-case semantics, exclude expanded from ROADMAP.md matching for
      the same structural reason, and report expanded/deferred counts in dry-run and final output)*
- [x] Confirm no archival selector in either file mentions `partial` or `blocked`:
      ```bash
      grep -niE 'partial|blocked' agent-system/extensions/core/commands/todo.md \
        agent-system/extensions/core/skills/skill-todo/SKILL.md
      ```
      Any hit must be unrelated to archival (review each). *(completed: two hits, both reviewed
      — `commands/todo.md` line 976 is prose stating partial/blocked are NOT archivable;
      `skill-todo/SKILL.md` line 53 is Stage 1.5's pre-existing reconcile-scan-targets query,
      unrelated to archival)*
- [x] Confirm no residual two-status filter remains:
      ```bash
      grep -n 'completed" or .status == "abandoned"' \
        agent-system/extensions/core/commands/todo.md \
        agent-system/extensions/core/skills/skill-todo/SKILL.md
      ```
      Every hit must be followed by `or .status == "expanded"`. *(completed: exactly one hit —
      the Step 5B del() filter itself — and it is followed by `or .status == "expanded"`)*
- [x] Confirm no `!=` was introduced into any jq expression in either file (Issue #1132 safety).
      *(completed: all `!=` occurrences are pre-existing prose/comments or the pre-existing
      sanctioned file-based-filter pattern; verified via `git diff` that none were added by this
      task's edits)*
- [x] Confirm no task-number citations landed in the deliverables:
      ```bash
      grep -nEi '\btasks? [0-9]+' agent-system/extensions/core/commands/todo.md \
        agent-system/extensions/core/skills/skill-todo/SKILL.md \
        agent-system/extensions/core/merge-sources/claudemd.md
      ```
      `(Task {N})` / `Task {N}` template placeholders in the ROADMAP-annotation examples are
      expected and fine; literal digits are not. *(completed: two hits, both pre-existing and
      confirmed via `git diff` to be outside this task's edits — `merge-sources/claudemd.md`'s
      commit-format example and `skill-todo/SKILL.md`'s vault-transition comment)*
- [x] Confirm the SOURCE-STORE RULE held — the working-tree diff touches only the three files in
      scope and nothing under `.claude/`:
      ```bash
      git status --short
      ```
      *(completed: nothing under `.claude/` is modified. `git status --short` also shows
      `.claude-extensions.json`, `lua/neotex/plugins/editor/which-key.lua`,
      `lua/neotex/plugins/tools/himalaya/utils/cli.lua`, and `specs/events.jsonl` as modified —
      these were already dirty before this task started (present in the session's initial git
      status from concurrent sibling task work) and are untouched by this task's commits, which
      are scoped exactly to the three in-scope files plus this task's own `specs/911_.../`
      artifacts)*
- [x] Confirm `merge-sources/claudemd.md` no longer groups `BLOCKED`/`PARTIAL` with "Terminal",
      and that its new wording agrees with `context/standards/status-markers.md`'s Validation
      Rules section (terminal = COMPLETED, ABANDONED, EXPANDED). Read `status-markers.md` for
      comparison only — do not modify it. *(completed: status-markers.md's transition diagram
      groups PARTIAL and BLOCKED with the non-terminal statuses, and its per-marker sections mark
      COMPLETED/ABANDONED/EXPANDED as terminal — matches claudemd.md's new two-bullet split)*

**Timing**: 0.25 hours

**Depends on**: 1, 3, 4

**Files to modify**:
- None (verification only)

**Verification**:
- All greps above return the expected results, with any exceptions individually justified.
- `git status --short` lists exactly the three in-scope files as modified.

---

## Testing & Validation

There is no executable test suite for these markdown command/skill definitions; validation is by
targeted inspection.

- [x] Both archival sites list exactly `{completed, abandoned, expanded}` as archivable.
- [x] `partial` and `blocked` appear in no archival selector in either file.
- [x] `expanded` tasks route to `completed_projects`; no third archive array was introduced.
- [x] The `del()` filter in `commands/todo.md` Step 5B subtracts deferred parent numbers.
      Verified against a representative state.json fixture (see Phase 3 deviation note); the
      plan's literal snippet needed a `. as $item |` binding fix to parse and behave correctly.
- [x] The defer guard's four edge cases are each handled explicitly at both sites: missing/empty
      `subtasks`, subtask absent from `active_projects`, subtask in a terminal status, subtask in
      a non-terminal status.
- [x] Expanded tasks are excluded from ROADMAP.md matching at both sites, with the structural
      reason stated.
- [x] Dry-run output at both sites shows expanded counts and deferred parents before any
      mutation.
- [x] `merge-sources/claudemd.md` separates terminal from exception states and agrees with
      `status-markers.md`.
- [x] `git status --short` shows nothing under `.claude/`; the three in-scope files plus this
      task's own `specs/911_.../` artifacts are the only paths this task's commits touched
      (pre-existing unrelated dirty files from concurrent sibling work are untouched — see
      Phase 5 task list above for the itemized list).
- [x] No task-number citations in any of the three files (two pre-existing hits reviewed and
      confirmed unrelated to this task's edits via `git diff`).

## Artifacts & Outputs

- `agent-system/extensions/core/commands/todo.md` (modified)
- `agent-system/extensions/core/skills/skill-todo/SKILL.md` (modified)
- `agent-system/extensions/core/merge-sources/claudemd.md` (modified)
- `specs/911_correct_terminal_status_taxonomy_and_todo_archival/summaries/01_terminal-status-taxonomy-archival-summary.md`

## Rollback/Contingency

All three files are markdown definitions with no build step, so rollback is a plain revert.

- Per-phase: `git checkout HEAD -- <file>` on a clean tree, or revert the phase's commit.
- Full: revert the phase commits in reverse order (5 -> 1). Phase 1 (`claudemd.md`) is fully
  independent of Phases 2-4 and can be kept or reverted separately.
- Contingency if the deferred-parent exclusion in Step 5B proves hard to express cleanly: land
  Phases 1, 2, and 4's status-widening without the guard, and file the guard as follow-up
  work — a widened filter without the guard still matches the archival behavior that
  `completed`/`abandoned` tasks already receive today, and is strictly better than the current
  permanently-unarchivable state. Do NOT ship a guard that defers the archive-list entry while
  leaving the blanket `del()` filter unamended; that combination silently drops the task from
  state.json and is worse than either alternative.
